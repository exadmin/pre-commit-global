@REM Registers 'hooks-global' as global-hooks folder irrelevantly to the place where the script was called from

@echo off
setlocal

if exist "%~dp0hooks-global" (
  git config --global core.hooksPath "%~dp0hooks-global"
  echo [OK] Global hooks are set to %~dp0hooks-global
) else (
  echo [ERROR] hooks-global folder not found at: "%~dp0hooks-global"
)

endlocal
pause