@echo off
:: ============================================================
:: install_scheduler.bat
:: Registers zkbio_sync.py to run automatically every morning
:: Run this once as Administrator on Windows
:: ============================================================

SET SCRIPT_DIR=%~dp0
SET TASK_NAME=ZKBioSchoolSync

:: Remove old task if exists
schtasks /Delete /TN "%TASK_NAME%" /F 2>nul

:: Create task: runs every weekday at 07:30 AM
schtasks /Create ^
  /TN "%TASK_NAME%" ^
  /TR "python \"%SCRIPT_DIR%zkbio_sync.py\"" ^
  /SC WEEKLY ^
  /D MON,TUE,WED,THU,FRI,SAT ^
  /ST 07:30 ^
  /RU SYSTEM ^
  /F

IF %ERRORLEVEL% EQU 0 (
  echo ✅  Scheduled task "%TASK_NAME%" created successfully.
  echo     Runs every weekday at 07:30 AM.
) ELSE (
  echo ❌  Failed. Make sure you are running as Administrator.
)
pause
