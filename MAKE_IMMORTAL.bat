@echo off
color 0A
echo ===================================================
echo      INSTALLING THE PHANTOM GHOST DAEMON
echo ===================================================
echo.
set VBS="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Phantom_Stealth.vbs"
echo Set WshShell = CreateObject("WScript.Shell") > %VBS%
echo WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Project Nexus PDF version\Phantom_Bot.ps1""", 0, False >> %VBS%
echo [+] Stealth Launcher injected into Windows Startup.
echo.
echo [+] Igniting Phantom Bot in the background...
wscript.exe %VBS%
echo.
echo [SUCCESS] The Bot is now IMMORTAL. 
echo It is running invisibly right now and will automatically start every time you turn on this laptop.
pause