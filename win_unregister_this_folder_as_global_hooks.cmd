@REM Unsets global git properties set by win_register_this_folder_as_global_hooks.cmd

@echo off
setlocal

set CURRENT=
for /f "delims=" %%i in ('git config --global --get core.hooksPath') do set CURRENT=%%i

if defined CURRENT (
  git config --global --unset core.hooksPath
  echo [OK] Global hooks are unset (was %CURRENT%)
) else (
  echo [INFO] core.hooksPath is not set
)

endlocal
pause
