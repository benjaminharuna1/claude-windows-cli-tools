@echo off
title Ollama Manager
setlocal

:: ===== CONFIG =====
set ollamaCmd=ollama
set startupFolder=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
set startupFile=%startupFolder%\ollama-autostart.bat

:menu
cls
echo ==============================
echo        OLLAMA MANAGER
echo ==============================
echo 1. Start Ollama Server
echo 2. Stop Ollama Server
echo 3. Check Status
echo 4. Enable Autostart
echo 5. Disable Autostart
echo 6. Exit
echo ==============================
set /p choice=Select an option: 

if "%choice%"=="1" goto start
if "%choice%"=="2" goto stop
if "%choice%"=="3" goto status
if "%choice%"=="4" goto enable
if "%choice%"=="5" goto disable
if "%choice%"=="6" exit

echo Invalid choice!
pause
goto menu

:start
echo Starting Ollama server...
start "" %ollamaCmd% serve
timeout /t 2 >nul
echo Done.
pause
goto menu

:stop
echo Stopping Ollama server...
taskkill /IM ollama.exe /F >nul 2>&1
echo Done.
pause
goto menu

:status
tasklist | findstr ollama >nul
if %errorlevel%==0 (
    echo Ollama is RUNNING
) else (
    echo Ollama is STOPPED
)
pause
goto menu

:enable
echo Enabling autostart...
echo @echo off > "%startupFile%"
echo start "" %ollamaCmd% serve >> "%startupFile%"
echo Autostart ENABLED
pause
goto menu

:disable
echo Disabling autostart...
if exist "%startupFile%" (
    del "%startupFile%"
    echo Autostart DISABLED
) else (
    echo Autostart already disabled
)
pause
goto menu