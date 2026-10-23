[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http

$BotToken  = "8848976862:AAEdKfpE2QDAnwpQSTwj0x-5Rri7flvgcUs"
$VaultPath = "/home/tejas/Project Nexus PDF version"
$SavePath  = "$VaultPath/09_Telegram_Uploads"
$apiUrl    = "https://api.telegram.org/bot$BotToken"

try {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -ne $PID -and $_.CommandLine -match "Phantom_Bot"
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

$IconFolder  = [char]::ConvertFromUtf32(0x1F4C1)
$IconFile    = [char]::ConvertFromUtf32(0x1F4C4)
$IconBack    = [char]::ConvertFromUtf32(0x2B05)
$IconHome    = [char]::ConvertFromUtf32(0x1F3E0)
$IconSearch  = [char]::ConvertFromUtf32(0x1F50D)
$IconBolt    = [char]::ConvertFromUtf32(0x26A1)
$IconCheck   = [char]::ConvertFromUtf32(0x2705)
$IconBook    = [char]::ConvertFromUtf32(0x1F4D6)
$IconRefresh = [char]::ConvertFromUtf32(0x1F504)
$IconRocket  = [char]::ConvertFromUtf32(0x1F680)
$IconChart   = [char]::ConvertFromUtf32(0x1F4CA)

$Global:PathToId = @{}
$Global:IdToPath = @{}
$Global:NextId   = 1

function Get-PathId([string]$FullPath) {
    $clean = $FullPath.TrimEnd('\').TrimEnd('/')
    if ($Global:PathToId.ContainsKey($clean)) { return $Global:PathToId[$clean] }
    $id = "$Global:NextId"
    $Global:NextId++
    $Global:PathToId[$clean] = $id
    $Global:IdToPath[$id] = $clean
    return $id
}

function Register-BotCommands {
    $cmdPayload = @{
        commands = @(
            @{ command = "fetch";  description = "Open Live Vault Navigator or search files" },
            @{ command = "manual"; description = "Read the Binary Cartel Guide & 9 Sections List" },
            @{ command = "vault";  description = "Open Main Vault Dashboard" }
        )
    }
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

function Send-CartelManual($ChatId, $EditMsgId = $null) {
    $rootId = Get-PathId -FullPath $VaultPath
    $sec9Id = Get-PathId -FullPath $SavePath

    $manualText = @"
$IconBook <b>THE BINARY CARTEL // TACTICAL MANUAL</b>
======================
<b>1. HOW TO BROWSE & OPEN FOLDERS:</b>
- Tap <b>$IconRocket OPEN MAIN VAULT (/fetch)</b> below (or type <code>/fetch</code> anytime).
- Every section and subfolder on your PC is scanned <b>100% LIVE</b>.
- Tap any <b>$IconFolder Folder</b> button to open its subjects/subfolders.
- Tap any <b>$IconFile File</b> button to beam that file straight to your phone.

<b>2. HOW TO FAST-SEARCH:</b>
- Type <code>/fetch nexus</code> or <code>/fetch geography</code> to jump straight to any folder or file.

======================
$IconBolt <b>THE 9 OFFICIAL VAULT SECTIONS:</b>
1. <b>01_Nexus</b> - Core Subject Folders, Chapters & Study Material
2. <b>02_The_Cartel</b> - High-Priority Tactical Resources & Elite Material
3. <b>03_PYQs</b> - Previous Year Question Papers & Practice Sets
4. <b>04_Short_Notes</b> - Quick Revision Notes, Summaries & Formula Sheets
5. <b>05_Cached</b> - Archived / Reserve Files & Temporary Storage
6. <b>06_Syllabus</b> - Official Curriculum & Exam Syllabus Trackers
7. <b>07_Specimens</b> - Sample Papers, Blueprints & Model Tests
8. <b>08_Maintenance</b> - System Tools, Logs & Vault Utilities
9. <b>09_Telegram_Uploads</b> - Quarantine Inbox for Incoming Telegram Drops
======================
<i>Tap an action button below:</i>
"@
    $rows = New-Object System.Collections.Generic.List[object]
    $row1 = New-Object System.Collections.Generic.List[object]
    $row1.Add(@{ text = "$IconRocket OPEN MAIN VAULT (/fetch)"; callback_data = "D:$rootId" })
    $rows.Add($row1)
    $row2 = New-Object System.Collections.Generic.List[object]
    $row2.Add(@{ text = "$IconFolder OPEN SEC 9 (UPLOADS)"; callback_data = "D:$sec9Id" })
    $rows.Add($row2)

    $payload = @{ chat_id = $ChatId; text = $manualText; parse_mode = "HTML"; reply_markup = @{ inline_keyboard = $rows } }
    $endpoint = "sendMessage"
    if ($EditMsgId) { $payload["message_id"] = $EditMsgId; $endpoint = "editMessageText" }
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 10 -Compress))
    try { Invoke-RestMethod -Uri "$apiUrl/$endpoint" -Method Post -Body $jsonBytes -ContentType "application/json; charset=utf-8" -TimeoutSec 15 | Out-Null } catch {}
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
        $lbl = "$IconFolder $($dir.Name.Replace('_', ' '))"
        if ($lbl.Length -gt 45) { $lbl = $lbl.Substring(0, 42) + "..." }
        $row = New-Object System.Collections.Generic.List[object]
        $row.Add(@{ text = $lbl; callback_data = "D:$id" })
        $rows.Add($row)
    }

    foreach ($file in $items.Files) {
        $id  = Get-PathId -FullPath $file.FullName
        $lbl = "$IconFile $($file.Name)"
        if ($lbl.Length -gt 45) { $lbl = $lbl.Substring(0, 42) + "..." }
        $row = New-Object System.Collections.Generic.List[object]
        $row.Add(@{ text = $lbl; callback_data = "F:$id" })
        $rows.Add($row)
    }

    if ($cleanCurrent -ne $cleanRoot) {
        $navRow   = New-Object System.Collections.Generic.List[object]
        $parent   = Split-Path -Path $cleanCurrent -Parent
        $parentId = Get-PathId -FullPath $parent
        $navRow.Add(@{ text = "$IconBack BACK"; callback_data = "D:$parentId" })
        $navRow.Add(@{ text = "$IconHome MAIN VAULT"; callback_data = "D:$rootId" })
        $rows.Add($navRow)
    }

    $utilRow = New-Object System.Collections.Generic.List[object]
    $utilRow.Add(@{ text = "$IconRefresh REFRESH LIVE"; callback_data = "R:$currentId" })
    $utilRow.Add(@{ text = "$IconBook MANUAL"; callback_data = "M:0" })
    $rows.Add($utilRow)

    $folderTitle = Split-Path -Path $cleanCurrent -Leaf
    if ($cleanCurrent -eq $cleanRoot) { $folderTitle = "THE BINARY CARTEL // MASTER VAULT" }

    $fCount    = $items.Folders.Count
    $fileCount = $items.Files.Count
    $timeStamp = Get-Date -Format "HH:mm:ss"

    $msgText = "$IconBolt <b>SECTOR:</b> <code>$folderTitle</code>`n"
    $msgText += "$IconChart <b>Live Index:</b> $fCount Folders | $fileCount Files <i>(Synced $timeStamp)</i>`n`n"
    if (($fCount + $fileCount) -eq 0) { $msgText += "<i>(Empty folder. Add files and tap REFRESH LIVE!)</i>" } 
    else { $msgText += "Tap any <b>Folder</b> to open it, or tap any <b>File</b> to download:" }

    $payload = @{ chat_id = $ChatId; text = $msgText; parse_mode = "HTML"; reply_markup = @{ inline_keyboard = $rows } }
    $endpoint = "sendMessage"
    if ($EditMsgId) { $payload["message_id"] = $EditMsgId; $endpoint = "editMessageText" }
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 10 -Compress))
    try { Invoke-RestMethod -Uri "$apiUrl/$endpoint" -Method Post -Body $jsonBytes -ContentType "application/json; charset=utf-8" -TimeoutSec 15 | Out-Null } catch {}
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

if (!(Test-Path $SavePath)) { New-Item -ItemType Directory -Force -Path $SavePath | Out-Null }
Register-BotCommands

try {
    $botInfo = Invoke-RestMethod -Uri "$apiUrl/getMe" -Method Get -TimeoutSec 10
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " [SYSTEM] PHANTOM BOT ONLINE: @$($botInfo.result.username)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
} catch {}

# --- HYPER-DRIVE WEBHOOK ENGINE ---
Stop-Process -Name "cloudflared" -Force -ErrorAction SilentlyContinue
$logFile = Join-Path $VaultPath "tunnel.log"
Remove-Item $logFile -ErrorAction SilentlyContinue

Write-Host "[SYSTEM] Starting Cloudflare Tunnel..." -ForegroundColor Yellow

# FIXED COMMAND: Pipes the output securely into tunnel.log
Start-Job -ScriptBlock {
    param($vPath)
    Set-Location $vPath
    cloudflared tunnel --url http://127.0.0.1:8443 2> tunnel.log
} -ArgumentList $VaultPath | Out-Null

$webhookUrl = $null
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $logFile) {
        $match = Select-String -Path $logFile -Pattern "https://[a-zA-Z0-9-]+\.trycloudflare\.com"
        if ($match) { $webhookUrl = $match.Matches[0].Value; break }
    }
}

if (!$webhookUrl) { Write-Host "[ERROR] Cloudflare Tunnel failed to start." -ForegroundColor Red; exit }

Write-Host "[SYSTEM] Tunnel Online: $webhookUrl" -ForegroundColor Cyan
Invoke-RestMethod -Uri "$apiUrl/setWebhook?url=$webhookUrl" -Method Post | Out-Null

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:8443/")
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
                elseif ($data -eq "M:0") {
                    Send-CartelManual -ChatId $chatId -EditMsgId $msgId
                    Invoke-RestMethod -Uri "$apiUrl/answerCallbackQuery" -Method Post -Body @{ callback_query_id = $cbId } | Out-Null
                }
                elseif ($data -match "^F:(\d+)$") {
                    $filePath = $Global:IdToPath[$matches[1]]
                    if ($filePath -and (Test-Path $filePath)) {
                        $fName = Split-Path $filePath -Leaf
                        Invoke-RestMethod -Uri "$apiUrl/answerCallbackQuery" -Method Post -Body @{ callback_query_id = $cbId; text = "Beaming $fName..." } | Out-Null
                        Send-TelegramFile -ChatId $chatId -FilePath $filePath
                    }
                }
            }
            elseif ($update.message) {
                $message = $update.message
                $chatId  = $message.chat.id
                $fileId  = $null
                $fileName = "Cartel_Drop_$(Get-Date -Format 'yyyyMMdd_HHmmss').pdf"

                if ($message.document) {
                    $fileId = $message.document.file_id
                    if ($message.document.file_name) { $fileName = $message.document.file_name }
                } elseif ($message.photo) {
                    $fileId   = $message.photo[-1].file_id
                    $fileName = "Cartel_Photo_$(Get-Date -Format 'yyyyMMdd_HHmmss').jpg"
                }

                if ($fileId) {
                    $fileInfo    = Invoke-RestMethod -Uri "$apiUrl/getFile?file_id=$fileId" -Method Get
                    $downloadUrl = "https://api.telegram.org/file/bot$BotToken/$($fileInfo.result.file_path)"
                    $dest        = Join-Path $SavePath $fileName
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $dest

                    Set-Location -Path $VaultPath
                    git add .
                    git commit -m "Auto-Drop via Telegram: $fileName"
                    git push

                    $rootId = Get-PathId -FullPath $VaultPath
                    $sec9Id = Get-PathId -FullPath $SavePath
                    $upRows = New-Object System.Collections.Generic.List[object]
                    $upRow  = New-Object System.Collections.Generic.List[object]
                    $upRow.Add(@{ text = "$IconFolder OPEN SEC 9"; callback_data = "D:$sec9Id" })
                    $upRow.Add(@{ text = "$IconHome MAIN VAULT"; callback_data = "D:$rootId" })
                    $upRows.Add($upRow)

                    $replyPayload = @{ chat_id = $chatId; text = "$IconCheck <b>Secured in Section 9 & Synced:</b> <code>$fileName</code>"; parse_mode = "HTML"; reply_markup = @{ inline_keyboard = $upRows } }
                    $replyBytes = [System.Text.Encoding]::UTF8.GetBytes(($replyPayload | ConvertTo-Json -Depth 10 -Compress))
                    Invoke-RestMethod -Uri "$apiUrl/sendMessage" -Method Post -Body $replyBytes -ContentType "application/json; charset=utf-8" | Out-Null
                }
                elseif ($message.text) {
                    $text = $message.text
                    if ($text -match "^/(manual|manul|help)\b") { Send-CartelManual -ChatId $chatId }
                    elseif ($text -match "^/(fetch|fectch|fecth|vault|start)\s*$") { Send-VaultMenu -ChatId $chatId -FolderPath $VaultPath }
                    elseif ($text -match "^/(fetch|fectch|fecth)\s+(.+)$") {
                        $query = $matches[2].Trim()
                        $ignoreFolders = @(".git", ".netlify", ".vscode", "node_modules")
                        $ignoreExts    = @(".ps1", ".bat", ".html", ".js", ".vbs")

                        $allItems = Get-ChildItem -Path $VaultPath -Recurse -ErrorAction SilentlyContinue | Where-Object {
                            $_.Name -match [regex]::Escape($query) -and ($ignoreFolders -notcontains $_.Name) -and ($ignoreExts -notcontains $_.Extension.ToLower()) -and ($_.Name -ne "index.html")
                        }

                        $matchedFolders = @($allItems | Where-Object { $_.PSIsContainer })
                        $matchedFiles   = @($allItems | Where-Object { !$_.PSIsContainer })

                        if ($matchedFolders.Count -eq 1 -and $matchedFiles.Count -eq 0) { Send-VaultMenu -ChatId $chatId -FolderPath $matchedFolders[0].FullName }
                        elseif (($matchedFolders.Count + $matchedFiles.Count) -gt 0) {
                            $rows = New-Object System.Collections.Generic.List[object]
                            foreach ($dir in ($matchedFolders | Select-Object -First 15)) {
                                $id  = Get-PathId -FullPath $dir.FullName
                                $lbl = "$IconFolder $($dir.Name.Replace('_', ' '))"
                                $row = New-Object System.Collections.Generic.List[object]
                                $row.Add(@{ text = $lbl; callback_data = "D:$id" })
                                $rows.Add($row)
                            }
                            foreach ($f in ($matchedFiles | Select-Object -First 20)) {
                                $id  = Get-PathId -FullPath $f.FullName
                                $lbl = "$IconFile $($f.Name)"
                                $row = New-Object System.Collections.Generic.List[object]
                                $row.Add(@{ text = $lbl; callback_data = "F:$id" })
                                $rows.Add($row)
                            }
                            $rootId  = Get-PathId -FullPath $VaultPath
                            $homeRow = New-Object System.Collections.Generic.List[object]
                            $homeRow.Add(@{ text = "$IconHome MAIN VAULT"; callback_data = "D:$rootId" })
                            $homeRow.Add(@{ text = "$IconBook MANUAL"; callback_data = "M:0" })
                            $rows.Add($homeRow)

                            $searchPayload = @{ chat_id = $chatId; text = "$IconSearch <b>Live Search Results for:</b> <code>$query</code>"; parse_mode = "HTML"; reply_markup = @{ inline_keyboard = $rows } }
                            $sBytes = [System.Text.Encoding]::UTF8.GetBytes(($searchPayload | ConvertTo-Json -Depth 10 -Compress))
                            Invoke-RestMethod -Uri "$apiUrl/sendMessage" -Method Post -Body $sBytes -ContentType "application/json; charset=utf-8" | Out-Null
                        }
                        else {
                            $rootId  = Get-PathId -FullPath $VaultPath
                            $errRows = New-Object System.Collections.Generic.List[object]
                            $errRow  = New-Object System.Collections.Generic.List[object]
                            $errRow.Add(@{ text = "$IconHome OPEN MAIN VAULT (/fetch)"; callback_data = "D:$rootId" })
                            $errRow.Add(@{ text = "$IconBook MANUAL"; callback_data = "M:0" })
                            $errRows.Add($errRow)
                            $errPayload = @{ chat_id = $chatId; text = "No folders or files matched <code>$query</code>. Tap below to browse all sections:"; parse_mode = "HTML"; reply_markup = @{ inline_keyboard = $errRows } }
                            $eBytes = [System.Text.Encoding]::UTF8.GetBytes(($errPayload | ConvertTo-Json -Depth 10 -Compress))
                            Invoke-RestMethod -Uri "$apiUrl/sendMessage" -Method Post -Body $eBytes -ContentType "application/json; charset=utf-8" | Out-Null
                        }
                    }
                }
            }
        } catch { Write-Host "[ERROR] $_" -ForegroundColor Red }
    }
    $response.StatusCode = 200
    $response.Close()
}