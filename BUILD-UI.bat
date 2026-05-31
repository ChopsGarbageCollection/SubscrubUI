@echo off
REM ============================================================================
REM SubScrubUI v1.1 - Build Script
REM This script compiles SubScrubUI-v1.1.ps1 into SubScrubUI.exe
REM Supports custom icons and includes proper error checking
REM ============================================================================

setlocal
title SubScrubUI v1.1 - Build Script

echo.
echo ========================================
echo   SubScrubUI v1.1 Build Script
echo ========================================
echo.

REM Check if script exists
if not exist "SubScrubUI-v1.1.ps1" (
    echo ERROR: SubScrubUI-v1.1.ps1 not found!
    echo.
    echo Please make sure the .ps1 file is in the same folder as BUILD-UI.bat
    echo.
    pause
    exit /b 1
)

echo [1/4] Checking for PS2EXE module...
powershell -NoProfile -ExecutionPolicy Bypass -Command "if (!(Get-Module -ListAvailable -Name ps2exe)) { Write-Host 'Installing PS2EXE module...' -ForegroundColor Yellow; Install-Module ps2exe -Scope CurrentUser -Force; Write-Host 'Installed!' -ForegroundColor Green } else { Write-Host 'Already installed' -ForegroundColor Green }"

echo.
echo [2/4] Checking for icon file...
if exist "SubScrub.ico" (
    echo ========================================
    echo   ICON FOUND: SubScrub.ico
    echo ========================================
    echo Your custom icon will be embedded!
    set USE_ICON=YES
) else (
    echo ========================================
    echo   NO ICON FILE FOUND
    echo ========================================
    echo.
    echo To use a custom icon:
    echo   1. Place SubScrub.ico in THIS folder
    echo   2. Run BUILD-UI.bat again
    echo.
    echo The .exe will use default icon for now.
    set USE_ICON=NO
)

echo.
echo [3/4] Compiling to .exe...
echo This may take 30-60 seconds...
echo.

REM Delete old exe files if they exist
if exist "SubScrubUI.exe" del /q "SubScrubUI.exe"
if exist "SubScrub-GUI.exe" del /q "SubScrub-GUI.exe"

REM Compile with or without icon
if "%USE_ICON%"=="YES" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-ps2exe -InputFile '.\SubScrubUI-v1.1.ps1' -OutputFile '.\SubScrubUI.exe' -noConsole -iconFile '.\SubScrub.ico' -title 'SubScrubUI v1.1' -version '1.1.0.0' -copyright '2024' -product 'SubScrubUI' -ErrorAction Stop; exit 0 } catch { Write-Host 'Error:' $_.Exception.Message -ForegroundColor Red; exit 1 }"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-ps2exe -InputFile '.\SubScrubUI-v1.1.ps1' -OutputFile '.\SubScrubUI.exe' -noConsole -title 'SubScrubUI v1.1' -version '1.1.0.0' -copyright '2024' -product 'SubScrubUI' -ErrorAction Stop; exit 0 } catch { Write-Host 'Error:' $_.Exception.Message -ForegroundColor Red; exit 1 }"
)

REM Check PowerShell exit code
if errorlevel 1 (
    echo.
    echo ========================================
    echo   COMPILATION FAILED
    echo ========================================
    echo.
    echo The PowerShell command failed.
    echo Check the error message above.
    echo.
    pause
    exit /b 1
)

echo.
echo [4/4] Verifying result...
timeout /t 2 /nobreak >nul

if exist "SubScrubUI.exe" (
    echo.
    echo ========================================
    echo   SUCCESS!
    echo ========================================
    echo.
    echo SubScrubUI.exe has been created!
    echo.
    for %%I in (SubScrubUI.exe) do echo Size: %%~zI bytes
    echo.
    if "%USE_ICON%"=="YES" (
        echo Custom icon: Included
    ) else (
        echo Custom icon: Not used
    )
    echo Application type: GUI ^(no console window^)
    echo.
    echo You can now double-click SubScrubUI.exe to run it!
    echo.
) else (
    echo.
    echo ========================================
    echo   FAILED!
    echo ========================================
    echo.
    echo SubScrubUI.exe was not created.
    echo.
    echo Possible issues:
    echo  - PS2EXE compilation error
    echo  - Syntax error in SubScrubUI-v1.1.ps1
    echo  - PowerShell execution policy
    echo  - Antivirus blocking .exe creation
    echo.
    echo Try this manual command in PowerShell:
    echo.
    if "%USE_ICON%"=="YES" (
        echo Invoke-ps2exe -InputFile "SubScrubUI-v1.1.ps1" -OutputFile "SubScrubUI.exe" -noConsole -iconFile "SubScrub.ico"
    ) else (
        echo Invoke-ps2exe -InputFile "SubScrubUI-v1.1.ps1" -OutputFile "SubScrubUI.exe" -noConsole
    )
    echo.
)

pause
