$BotToken = "8606203433:AAHMsgyuFeRJuxvkQ28r8Ge8mcGz3dsPE0k"
$SavePath = "C:\Project Nexus PDF version\09_Telegram_Uploads"

if (!(Test-Path $SavePath)) { New-Item -ItemType Directory -Force -Path $SavePath | Out-Null }

$apiUrl = "https://api.telegram.org/bot$BotToken"
$offset = 0

Write-Host "🤖 CARTEL-DROP BOT ONLINE. Send files on Telegram!..." -ForegroundColor Cyan

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
            } elseif ($message.photo) {
                $fileId = $message.photo[-1].file_id
                $fileName = "Cartel_Photo_$(Get-Date -Format 'yyyyMMdd_HHmmss').jpg"
            }

            if ($fileId) {
                $fileInfo = Invoke-RestMethod -Uri "$apiUrl/getFile?file_id=$fileId" -Method Get
                $downloadUrl = "https://api.telegram.org/file/bot$BotToken/$($fileInfo.result.file_path)"
                Invoke-WebRequest -Uri $downloadUrl -OutFile (Join-Path $SavePath $fileName)
                Write-Host "✅ Downloaded to Sec 9: $fileName" -ForegroundColor Green
            }
        }
    } catch { Start-Sleep -Seconds 2 }
    Start-Sleep -Seconds 1
}