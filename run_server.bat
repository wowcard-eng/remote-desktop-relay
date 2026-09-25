@echo off
title Remote Desktop Relay Server
echo ========================================================
echo   Starting Remote Desktop Cloud Relay Server
echo ========================================================
echo.

where node >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Node.js found. Starting Node.js Relay Server...
    cd /d "%~dp0server"
    if not exist node_modules (
        echo Installing dependencies (ws)...
        call npm install
    )
    node relay_server.js
) else (
    echo Node.js not found in PATH, checking Python...
    where python >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        echo [OK] Python found. Starting Python Relay Server...
        cd /d "%~dp0server"
        python relay_server.py
    ) else (
        echo [ERROR] Neither Node.js nor Python was found!
        echo Please install Node.js or Python to run the server.
        pause
    )
)
pause
