# 1. FORCE WINDOWS TO USE MODERN SECURITY
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BotToken = "8853585888:AAEPiqqdpL5HuAvbPstEYNUXIA616p6GaNI"
$SavePath = "C:\Project Nexus PDF version\09_Telegram_Uploads"

try {
    if (!(Test-Path $SavePath)) { New-Item -ItemType Directory -Force -Path $SavePath | Out-Null }

    $apiUrl = "https://api.telegram.org/bot$BotToken"
    $offset = 0

    Write-Host "[SYSTEM] CARTEL-DROP BOT ONLINE. Waiting for files from Telegram..." -ForegroundColor Cyan

    while ($true) {
        try {
            $updates = Invoke-RestMethod -Uri "$apiUrl/getUpdates?offset=$offset&timeout=10" -Method Get
            foreach ($update in $updates.result) {
                $offset = $update.update_id + 1
                $message = $update.message
                
                $fileId = $null
                $fileName = "Cartel_Drop_$(Get-Date -Format 'yyyyMMdd_HHmmss').pdf"

                if ($message.document) {
                    $fileId = $message.document.file_id
                    if ($message.document.file_name) { $fileName = $message.document.file_name }
                    Write-Host "[+] Incoming Document Detected: $fileName" -ForegroundColor Yellow
                } elseif ($message.photo) {
                    $fileId = $message.photo[-1].file_id
                    $fileName = "Cartel_Photo_$(Get-Date -Format 'yyyyMMdd_HHmmss').jpg"
                    Write-Host "[+] Incoming Photo Detected: $fileName" -ForegroundColor Yellow
                }

                if ($fileId) {
                    Write-Host "[~] Downloading from Telegram servers..." -ForegroundColor DarkGray
                    $fileInfo = Invoke-RestMethod -Uri "$apiUrl/getFile?file_id=$fileId" -Method Get
                    $downloadUrl = "https://api.telegram.org/file/bot$BotToken/$($fileInfo.result.file_path)"
                    $dest = Join-Path $SavePath $fileName
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $dest
                    Write-Host "[OK] Downloaded to Sec 9: $fileName" -ForegroundColor Green
                }
            }
        } catch { 
            Write-Host "[!] CONNECTION ERROR: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Seconds 2 
        }
        Start-Sleep -Seconds 1
    }
} catch {
    Write-Host "[FATAL] ERROR CRASH: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press ENTER to close the window. Read the error above first!"
}