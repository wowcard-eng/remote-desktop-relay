@echo off
title TeamViewer Remote Desktop - Windows Host
echo ========================================================
echo   Starting TeamViewer Remote Control - Windows Host
echo ========================================================
echo.

python --version >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python is not installed or not in PATH!
    echo Please install Python 3.10+ from python.org
    pause
    exit /b
)

echo [1/2] Checking Python dependencies...
python -m pip install -q -r "%~dp0host\requirements.txt"

echo [2/2] Launching Windows Host Engine...
python "%~dp0host\windows_host.py"

pause
