param([switch]$RunImplementation)
$ErrorActionPreference='Stop'
$finalRoot=$PSScriptRoot
$pythonExe='C:\Users\33791\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
Push-Location -LiteralPath $finalRoot
try {
 & $pythonExe setup_project.py
 if($LASTEXITCODE){throw 'Reference import failed'}
 & $pythonExe apply_adaptations.py
 if($LASTEXITCODE){throw 'Adaptations failed'}
 & $pythonExe build_firmware.py
 if($LASTEXITCODE){throw 'Firmware build failed'}
 & $pythonExe generate_soc.py
 if($LASTEXITCODE){throw 'Project generation failed'}
 if($RunImplementation) {
   & 'D:\pango\PDS_2022.2-SP1-Lite\bin\pds_shell.exe' -project FINAL.pds -run pnr *> build/pds-build.log
   $buildText=Get-Content build/pds-build.log -Raw
   if($LASTEXITCODE -or $buildText -match '(?m)^E:' -or !$buildText.Contains('Process "Place & Route" done.')) {
      throw 'PDS implementation failed; see build/pds-build.log'
   }
 }
} finally { Pop-Location }
