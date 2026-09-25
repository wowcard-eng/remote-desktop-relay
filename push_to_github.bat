@echo off
title Push Remote Desktop to GitHub
echo ========================================================
echo   Pushing code to GitHub: wowcard-eng/remote-desktop-relay
echo ========================================================
echo.

git remote remove origin 2>nul
git remote add origin https://github.com/wowcard-eng/remote-desktop-relay.git
git branch -M main

echo Running git push...
git push -u origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo [SUCCESS] Code successfully pushed to GitHub!
    echo Now open Render.com and connect your repository!
    echo ========================================================
) else (
    echo.
    echo [ERROR] Git push failed. Please check login / credentials.
)
pause
