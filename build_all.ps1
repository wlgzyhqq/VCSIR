param([switch]$RunImplementation,[switch]$GenerateBitstream)
if($GenerateBitstream){$RunImplementation=$true}
$ErrorActionPreference='Stop'
$finalRoot=$PSScriptRoot
$pythonExe='C:\Users\33791\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
Push-Location -LiteralPath $finalRoot
try {
 if(!(Test-Path 'ipcore/ddr3_test/ddr3_test.idf')) {
   & $pythonExe import_ddr_ip.py
   if($LASTEXITCODE){throw 'DDR IP import failed'}
 }
 & $pythonExe setup_project.py
 if($LASTEXITCODE){throw 'Reference import failed'}
 & $pythonExe apply_adaptations.py
 if($LASTEXITCODE){throw 'Adaptations failed'}
 & $pythonExe build_firmware.py
 if($LASTEXITCODE){throw 'Firmware build failed'}
 & $pythonExe generate_soc.py
 if($LASTEXITCODE){throw 'Project generation failed'}
 & $pythonExe check_ddr_project.py
 if($LASTEXITCODE){throw 'DDR project static checks failed'}
 if($RunImplementation) {
   $taskRunAction='pnr'
   if($GenerateBitstream){$taskRunAction='gen_bit_stream'}
   & 'D:\pango\PDS_2022.2-SP1-Lite\bin\pds_shell.exe' -project FINAL.pds -run $taskRunAction *> build/pds-ddr-build.log
   $buildText=Get-Content build/pds-ddr-build.log -Raw
   if($LASTEXITCODE -or $buildText -match '(?m)^E:' -or !$buildText.Contains('Process "Place & Route" done.')) {
      throw 'PDS DDR implementation failed; see build/pds-ddr-build.log'
   }
   $taskTimingText=Get-Content 'place_route/final_top_timing_summary_after_hold_fix.txt' -Raw
   if(!$taskTimingText.Contains('All Constraints Met')){throw 'DDR design routed but timing did not close; see place_route timing summary'}
   if($GenerateBitstream -and !(Test-Path 'generate_bitstream/final_top.sbit')){throw 'Bitstream output missing'}
 }
} finally { Pop-Location }
