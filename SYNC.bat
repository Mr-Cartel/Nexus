@echo off
:: 1. Convert Word to PDF
powershell -ExecutionPolicy Bypass -File cartel-sync.ps1

:: 2. Run the Infinite Builder
powershell -ExecutionPolicy Bypass -File nexus_builder.ps1

echo.
echo =========================================
echo LOCAL VAULT UPDATED SUCCESSFULLY! 
echo Netlify upload is disabled.
echo =========================================
pause