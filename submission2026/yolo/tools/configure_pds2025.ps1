$ErrorActionPreference = 'Stop'
$taskRoot = 'C:\Users\33791\Desktop\project\learn verilog\final_yolo'
$outputDir = Join-Path $taskRoot 'output\pds2025'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$reportPath = Join-Path $outputDir 'configuration.json'
$report = [ordered]@{ started=(Get-Date).ToString('o'); status='starting'; modelSimLicenseUnchanged=$false; existingAdaptersUnchanged=$false }
function Save-Report { $report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $reportPath -Encoding UTF8 }
Save-Report
try {
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
 if(-not $isAdmin){ throw 'Administrator token required to create a dedicated TAP adapter.' }
 $licenseSource = 'D:\BaiduNetdiskDownload\紫光同创PDS软件及license\小眼睛FPGA--license\虚拟网卡设置MAC\license\new_pds_00e04cf107df.lic'
 $licenseDir = 'D:\pango\licenses\pds2025'
 $licenseTarget = Join-Path $licenseDir 'new_pds_00e04cf107df.lic'
 $adapterName = 'PDS-License-2025'
 $before = @(Get-NetAdapter -IncludeHidden | Select-Object Name,InterfaceDescription,InterfaceGuid,MacAddress,Status)
 $report['adaptersBefore'] = $before
 $report['previousPangoLicenseUser'] = [Environment]::GetEnvironmentVariable('PANGO_LICENSE_FILE','User')
 $report['previousLmLicenseUser'] = [Environment]::GetEnvironmentVariable('LM_LICENSE_FILE','User')
 $report['previousLmLicenseMachine'] = [Environment]::GetEnvironmentVariable('LM_LICENSE_FILE','Machine')
 $existing = @(Get-NetAdapter -IncludeHidden | Where-Object Name -eq $adapterName)
 if($existing.Count -gt 1){ throw 'Dedicated adapter name is ambiguous.' }
 if($existing.Count -eq 0){
  $report['status']='creating_dedicated_adapter'; Save-Report
  $helper = 'D:\Program Files\TAP-Windows\bin\tapinstall.exe'
  $inf = 'D:\Program Files\TAP-Windows\driver\OemVista.inf'
  if((Get-AuthenticodeSignature -LiteralPath $helper).Status -ne 'Valid'){ throw 'TAP helper signature not valid.' }
  & $helper install $inf tap0901 2>&1 | Out-File -LiteralPath (Join-Path $outputDir 'tapinstall.log') -Encoding UTF8
  if($LASTEXITCODE -notin @(0,1)){ throw "TAP install returned $LASTEXITCODE" }
  $adapter = @()
  for($attempt=0;$attempt -lt 30;$attempt++){
   $adapter = @(Get-NetAdapter -IncludeHidden | Where-Object { $_.InterfaceDescription -like '*TAP-Windows*' -and $_.InterfaceGuid -notin $before.InterfaceGuid })
   if($adapter.Count -gt 0){ break }
   Start-Sleep -Milliseconds 500
  }
  if($adapter.Count -ne 1){ throw 'Cannot uniquely identify newly created TAP adapter; existing adapters left unchanged.' }
  Rename-NetAdapter -Name $adapter[0].Name -NewName $adapterName
 } else {
  if($existing[0].InterfaceDescription -notlike '*TAP-Windows*'){ throw 'Dedicated name belongs to another device; refusing to change it.' }
 }
 $report['status']='setting_dedicated_MAC'; Save-Report
 Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword 'MAC' -RegistryValue '00E04CF107DF' -NoRestart
 Restart-NetAdapter -Name $adapterName -Confirm:$false
 for($attempt=0;$attempt -lt 30;$attempt++){
  $adapter = Get-NetAdapter -Name $adapterName
  if($adapter.MacAddress.Replace('-','').ToUpperInvariant() -eq '00E04CF107DF'){ break }
  Start-Sleep -Milliseconds 500
 }
 if($adapter.MacAddress.Replace('-','').ToUpperInvariant() -ne '00E04CF107DF'){ throw 'Dedicated MAC did not apply.' }
 New-Item -ItemType Directory -Path $licenseDir -Force | Out-Null
 Copy-Item -LiteralPath $licenseSource -Destination $licenseTarget -Force
 if((Get-FileHash -LiteralPath $licenseSource).Hash -ne (Get-FileHash -LiteralPath $licenseTarget).Hash){ throw 'License copy hash mismatch.' }
 [Environment]::SetEnvironmentVariable('PANGO_LICENSE_FILE',$licenseTarget,'User')
 $report['licensePath']=$licenseTarget
 $report['licenseSHA256']=(Get-FileHash -LiteralPath $licenseTarget).Hash
 $report['adapter']=Get-NetAdapter -Name $adapterName | Select-Object Name,InterfaceDescription,InterfaceGuid,MacAddress,Status
 $report['modelSimLicenseUnchanged']=([Environment]::GetEnvironmentVariable('LM_LICENSE_FILE','User') -eq $report.previousLmLicenseUser -and [Environment]::GetEnvironmentVariable('LM_LICENSE_FILE','Machine') -eq $report.previousLmLicenseMachine)
 $after = @(Get-NetAdapter -IncludeHidden)
 $unchanged = $true
 foreach($original in $before){
  if($original.Name -eq $adapterName){ continue }
  $current = @($after | Where-Object InterfaceGuid -eq $original.InterfaceGuid)
  if($current.Count -ne 1 -or $current[0].MacAddress -ne $original.MacAddress -or $current[0].Name -ne $original.Name){ $unchanged=$false }
 }
 $report['existingAdaptersUnchanged']=$unchanged
 if(-not $unchanged -or -not $report.modelSimLicenseUnchanged){ throw 'Baseline preservation check failed.' }
 $report['status']='configured_pending_PDS_validation'
} catch {
 $report['status']='failed';$report['error']=$_.Exception.Message
} finally {
 $report['finished']=(Get-Date).ToString('o'); Save-Report
}
