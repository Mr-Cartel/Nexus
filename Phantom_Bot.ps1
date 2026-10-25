[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http

$BotToken  = "8848976862:AAEdKfpE2QDAnwpQSTwj0x-5Rri7flvgcUs"
$VaultPath = "/home/tejas/Project Nexus PDF version"
$apiUrl    = "https://api.telegram.org/bot$BotToken"

try {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -ne $PID -and $_.CommandLine -match "Phantom_Bot"
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

$Global:PathToId = @{}
$Global:IdToPath = @{}
$Global:NextId   = 1
$Global:PendingUploads = @{}

function Get-PathId([string]$FullPath) {
    $clean = $FullPath.TrimEnd('\').TrimEnd('/')
    if ($Global:PathToId.ContainsKey($clean)) { return $Global:PathToId[$clean] }
    $id = "$Global:NextId"; $Global:NextId++
    $Global:PathToId[$clean] = $id; $Global:IdToPath[$id] = $clean
    return $id
}

function Register-BotCommands {
    $cmdPayload = @{ commands = @(
        @{ command = "vault"; description = "Open Main Vault Dashboard" },
        @{ command = "sync"; description = "Pull latest files from GitHub (Sync.bat)" }
    )}
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($cmdPayload | ConvertTo-Json -Depth 5 -Compress))
    try { Invoke-RestMethod -Uri "$apiUrl/setMyCommands" -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -TimeoutSec 10 | Out-Null } catch {}
}

function Get-CleanVaultItems([string]$FolderPath) {
    $ignoreFolders = @(".git", ".netlify", ".vscode", "node_modules")
    $ignoreExts    = @(".ps1", ".bat", ".html", ".js", ".vbs")
    $ignoreNames   = @(".gitignore", "vault_index.js", "index.html")

    $all = Get-ChildItem -Path $FolderPath -Force -ErrorAction SilentlyContinue | Sort-Object Name
    $folders = New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]
    $files   = New-Object System.Collections.Generic.List[System.IO.FileInfo]

    foreach ($item in $all) {
        if ($item.Attributes -band [System.IO.FileAttributes]::Hidden) { continue }
        if ($item.PSIsContainer) {
            if ($ignoreFolders -notcontains $item.Name) { $folders.Add($item) }
        } else {
            if (($ignoreExts -notcontains $item.Extension.ToLower()) -and ($ignoreNames -notcontains $item.Name.ToLower())) { $files.Add($item) }
        }
    }
    return @{ Folders = $folders; Files = $files }
}

function Send-VaultMenu($ChatId, [string]$FolderPath, $EditMsgId = $null) {
    if (!(Test-Path $FolderPath)) { return }
    $cleanCurrent = $FolderPath.TrimEnd('\').TrimEnd('/')
    $cleanRoot    = $VaultPath.TrimEnd('\').TrimEnd('/')
    $currentId    = Get-PathId -FullPath $cleanCurrent
    $rootId       = Get-PathId -FullPath $cleanRoot

    $items = Get-CleanVaultItems -FolderPath $cleanCurrent
    $rows  = New-Object System.Collections.Generic.List[object]

    foreach ($dir in $items.Folders) {
        $id  = Get-PathId -FullPath $dir.FullName
        $lbl = "📁 $($dir.Name.Replace('_', ' '))"
        if ($lbl.Length -gt 45) { $lbl = $lbl.Substring(0, 42) + "..." }
        $row = New-Object System.Collections.Generic.List[object]
        $row.Add(@{ text = $lbl; callback_data = "D:$id" })
        $rows.Add($row)
    }

    foreach ($file in $items.Files) {
        $id  = Get-PathId -FullPath $file.FullName
        $lbl = "📄 $($file.Name)"
        if ($lbl.Length -gt 45) { $lbl = $lbl.Substring(0, 42) + "..." }
        $row = New-Object System.Collections.Generic.List[object]
        $row.Add(@{ text = $lbl; callback_data = "F:$id" })
        $rows.Add($row)
    }

    if ($cleanCurrent -ne $cleanRoot) {
        $navRow = New-Object System.Collections.Generic.List[object]
        $parent = Split-Path -Path $cleanCurrent -Parent
        $parentId = Get-PathId -FullPath $parent
        $navRow.Add(@{ text = "⬅ BACK"; callback_data = "D:$parentId" })
        $navRow.Add(@{ text = "🏠 MAIN VAULT"; callback_data = "D:$rootId" })
        $rows.Add($navRow)
    }

    if ($Global:PendingUploads.ContainsKey($ChatId)) {
        $dropRow = New-Object System.Collections.Generic.List[object]
        $dropRow.Add(@{ text = "✅ DROP FILE IN THIS FOLDER"; callback_data = "SAVE:$currentId" })
        $rows.Add($dropRow)
        $msgText = "⚠️ <b>PENDING UPLOAD DETECTED</b>`nClick through your folders above. When you are in the correct folder, tap the <b>DROP FILE</b> button below.`n`n📍 <b>CURRENT LOCATION:</b>`n<code>$cleanCurrent</code>"
    } else {
        $msgText = "⚡ <b>SECTOR:</b> <code>$cleanCurrent</code>`nTap any folder to open it, or file to download:"
        $utilRow = New-Object System.Collections.Generic.List[object]
        $utilRow.Add(@{ text = "🔄 REFRESH LIVE"; callback_data = "R:$currentId" })
        $rows.Add($utilRow)
    }

    $payload = @{ chat_id = $ChatId; text = $msgText; parse_mode = "HTML"; reply_markup = @{ inline_keyboard = $rows } }
    $endpoint = $EditMsgId ? "editMessageText" : "sendMessage"
    if ($EditMsgId) { $payload["message_id"] = $EditMsgId }
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 10 -Compress))
    try { Invoke-RestMethod -Uri "$apiUrl/$endpoint" -Method Post -Body $jsonBytes -ContentType "application/json; charset=utf-8" | Out-Null } catch {}
}

function Send-TelegramFile($ChatId, [string]$FilePath) {
    [System.Net.ServicePointManager]::Expect100Continue = $false
    $ThreadCode = {
        param($cId, $fPath, $url)
        try {
            $client = New-Object System.Net.Http.HttpClient
            $form   = New-Object System.Net.Http.MultipartFormDataContent
            $stream = [System.IO.File]::OpenRead($fPath)
            $form.Add((New-Object System.Net.Http.StringContent($cId)), "chat_id")
            $form.Add((New-Object System.Net.Http.StreamContent($stream)), "document", [System.IO.Path]::GetFileName($fPath))
            $null = $client.PostAsync($url, $form).Result
            $stream.Close(); $client.Dispose()
        } catch {}
    }
    $ps = [powershell]::Create().AddScript($ThreadCode).AddArgument($ChatId).AddArgument($FilePath).AddArgument("$apiUrl/sendDocument")
    $null = $ps.BeginInvoke()
}

Register-BotCommands

try {
    $botInfo = Invoke-RestMethod -Uri "$apiUrl/getMe" -Method Get -TimeoutSec 10
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " [SYSTEM] PHANTOM BOT ONLINE: @$($botInfo.result.username)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
} catch {}

# --- HYPER-DRIVE WEBHOOK ENGINE (HOST HEADER FIX APPLIED) ---
Stop-Process -Name "cloudflared" -Force -ErrorAction SilentlyContinue
$logFile = Join-Path $VaultPath "tunnel.log"
Remove-Item $logFile -ErrorAction SilentlyContinue

Write-Host "[SYSTEM] Starting Cloudflare Tunnel..." -ForegroundColor Yellow
Start-Job -ScriptBlock {
    param($vPath)
    Set-Location $vPath
    cloudflared tunnel --url http://127.0.0.1:8443 --http-host-header "127.0.0.1" 2> tunnel.log
} -ArgumentList $VaultPath | Out-Null

$webhookUrl = $null
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $logFile) {
        $match = Select-String -Path $logFile -Pattern "https://[a-zA-Z0-9-]+\.trycloudflare\.com"
        if ($match) { $webhookUrl = $match.Matches[0].Value.Trim(); break }
    }
}
if (!$webhookUrl) { Write-Host "[ERROR] Cloudflare Tunnel failed to start." -ForegroundColor Red; exit }

Write-Host "[SYSTEM] Tunnel Online: $webhookUrl" -ForegroundColor Cyan
Invoke-RestMethod -Uri "$apiUrl/setWebhook?url=$webhookUrl" -Method Post | Out-Null

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:8443/")
$listener.Prefixes.Add("http://localhost:8443/")
$listener.Start()
Write-Host "[SYSTEM] WEBHOOK ENGINE LISTENING - 0ms LATENCY ACTIVE" -ForegroundColor Green

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    if ($request.HttpMethod -eq 'POST') {
        try {
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $json = $reader.ReadToEnd()
            $update = $json | ConvertFrom-Json

            if ($update.callback_query) {
                $cb     = $update.callback_query
                $cbId   = $cb.id
                $chatId = $cb.message.chat.id
                $msgId  = $cb.message.message_id
                $data   = $cb.data

                if ($data -match "^D:(\d+)$") {
                    $dirPath = $Global:IdToPath[$matches[1]]
                    if ($dirPath -and (Test-Path $dirPath)) { Send-VaultMenu -ChatId $chatId -FolderPath $dirPath -EditMsgId $msgId }
                    Invoke-RestMethod -Uri "$apiUrl/answerCallbackQuery" -Method Post -Body @{ callback_query_id = $cbId } | Out-Null
                }
                elseif ($data -match "^R:(\d+)$") {
                    $dirPath = $Global:IdToPath[$matches[1]]
                    if ($dirPath -and (Test-Path $dirPath)) { Send-VaultMenu -ChatId $chatId -FolderPath $dirPath -EditMsgId $msgId }
                    Invoke-RestMethod -Uri "$apiUrl/answerCallbackQuery" -Method Post -Body @{ callback_query_id = $cbId; text = "Updated live from PC!" } | Out-Null
                }
                elseif ($data -match "^F:(\d+)$") {
                    $filePath = $Global:IdToPath[$matches[1]]
                    if ($filePath -and (Test-Path $filePath)) {
                        $fName = Split-Path $filePath -Leaf
                        Invoke-RestMethod -Uri "$apiUrl/answerCallbackQuery" -Method Post -Body @{ callback_query_id = $cbId; text = "Beaming $fName..." } | Out-Null
                        Send-TelegramFile -ChatId $chatId -FilePath $filePath
                    }
                }
                elseif ($data -match "^SAVE:(\d+)$") {
                    $dirPath = $Global:IdToPath[$matches[1]]
                    if ($dirPath -and $Global:PendingUploads.ContainsKey($chatId)) {
                        $fileInfo = $Global:PendingUploads[$chatId]
                        $fileId = $fileInfo.fileId
                        $fileName = $fileInfo.fileName
                        $Global:PendingUploads.Remove($chatId)

                        Invoke-RestMethod -Uri "$apiUrl/answerCallbackQuery" -Method Post -Body @{ callback_query_id = $cbId; text = "Saving to folder..." } | Out-Null
                        Invoke-RestMethod -Uri "$apiUrl/editMessageText" -Method Post -Body @{ chat_id = $chatId; message_id = $msgId; text = "⏳ <b>Downloading & Syncing to GitHub...</b>"; parse_mode = "HTML" } | Out-Null

                        $fileReq = Invoke-RestMethod -Uri "$apiUrl/getFile?file_id=$fileId" -Method Get
                        $downloadUrl = "https://api.telegram.org/file/bot$BotToken/$($fileReq.result.file_path)"
                        $dest = Join-Path $dirPath $fileName
                        Invoke-WebRequest -Uri $downloadUrl -OutFile $dest

                        Set-Location -Path $VaultPath
                        git add .
                        git commit -m "Auto-Drop: $fileName"
                        git push

                        Send-VaultMenu -ChatId $chatId -FolderPath $dirPath -EditMsgId $msgId
                    } else {
                        Invoke-RestMethod -Uri "$apiUrl/answerCallbackQuery" -Method Post -Body @{ callback_query_id = $cbId; text = "Error: Upload expired." } | Out-Null
                    }
                }
            }
            elseif ($update.message) {
                $message = $update.message
                $chatId  = $message.chat.id

                if ($message.document -or $message.photo) {
                    $fileId = $null
                    $fileName = "Upload_$(Get-Date -Format 'yyyyMMdd_HHmmss').pdf"
                    if ($message.document) {
                        $fileId = $message.document.file_id
                        if ($message.document.file_name) { $fileName = $message.document.file_name }
                    } elseif ($message.photo) {
                        $fileId = $message.photo[-1].file_id
                        $fileName = "Photo_$(Get-Date -Format 'yyyyMMdd_HHmmss').jpg"
                    }
                    $Global:PendingUploads[$chatId] = @{ fileId = $fileId; fileName = $fileName }
                    Send-VaultMenu -ChatId $chatId -FolderPath $VaultPath
                }
                elseif ($message.text) {
                    $text = $message.text
                    if ($text -match "^/(fetch|vault|start)\b") {
                        $Global:PendingUploads.Remove($chatId)
                        Send-VaultMenu -ChatId $chatId -FolderPath $VaultPath
                    }
                    elseif ($text -match "^/sync\b") {
                        Set-Location -Path $VaultPath
                        $gitOutput = git pull 2>&1
                        $msg = "🔄 <b>Git Pull Executed</b>`n<code>$gitOutput</code>"
                        Invoke-RestMethod -Uri "$apiUrl/sendMessage" -Method Post -Body @{ chat_id = $chatId; text = $msg; parse_mode = "HTML" } | Out-Null
                        Send-VaultMenu -ChatId $chatId -FolderPath $VaultPath
                    }
                }
            }
        } catch { Write-Host "[ERROR] $_" -ForegroundColor Red }
        $response.StatusCode = 200
        $response.Close()
    }
}