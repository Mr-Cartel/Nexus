@echo off
:: 1. Convert Word to PDF
powershell -ExecutionPolicy Bypass -File cartel-sync.ps1

:: 2. Run the Infinite Builder
powershell -ExecutionPolicy Bypass -File nexus_builder.ps1

:: 3. The Infinite Free Global Upload
echo.
echo Pushing updates to the global vault...
git add .
git commit -m "Automated Vault Update"
git push origin main

echo.
echo =========================================
echo VAULT SUCCESSFULLY PUSHED TO THE WEB! 
echo =========================================
pause