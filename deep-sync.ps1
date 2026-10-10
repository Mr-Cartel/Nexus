$utf8 = New-Object System.Text.UTF8Encoding $False

Write-Host "Cloning Deep Architecture to Short Notes..." -ForegroundColor Cyan

$subjects = @("Biology", "Chemistry", "Computer Applications", "English Language", "English Literature", "Geography", "Hindi", "History and Civics", "Maths", "Physics")
$baseDest = (Resolve-Path "04_Short_Notes").Path

foreach ($sub in $subjects) {
    $shortNotesSub = Join-Path $baseDest $sub
    if (!(Test-Path $shortNotesSub)) { New-Item -ItemType Directory -Path $shortNotesSub | Out-Null }
    
    foreach ($sec in @("01_Nexus", "02_The_Cartel")) {
        $srcPath = "$sec\$sub"
        if (Test-Path $srcPath) {
            $srcResolved = (Resolve-Path $srcPath).Path
            $allDirs = Get-ChildItem -Path $srcResolved -Recurse -Directory
            foreach ($dir in $allDirs) {
                $targetPath = $dir.FullName.Replace($srcResolved, $shortNotesSub)
                if (!(Test-Path $targetPath)) { New-Item -ItemType Directory -Path $targetPath | Out-Null }
            }
        }
    }
}

Write-Host "Deep Sync Complete. Generating UI for Short Notes..." -ForegroundColor Cyan

function Build-UI ($path) {
    if (!(Test-Path $path)) { return }
    $dirs = Get-ChildItem -Path $path -Directory
    foreach ($dir in $dirs) {
        $dirName = $dir.Name
        $html = "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'><title>$dirName</title><style>body{background:#0a0a0a;color:#00ffcc;font-family:monospace;text-align:center;margin:0;padding:40px;}a{text-decoration:none;}h1{font-size:2.5em;text-shadow:0 0 15px #00ffcc;text-transform:uppercase;margin-bottom:20px;}.back-btn{display:inline-block;padding:10px 20px;background:#222;color:#fff;border-radius:5px;border:1px solid #444;margin-bottom:30px;transition:0.3s;}.back-btn:hover{background:#00ffcc;color:#000;}.grid{display:flex;flex-wrap:wrap;justify-content:center;gap:15px;max-width:1200px;margin:0 auto;}.card{background:#141414;border:1px solid #333;border-radius:8px;padding:15px 20px;font-size:1.1em;font-weight:bold;cursor:pointer;transition:0.3s;color:#fff;min-width:250px;text-align:left;}.card:hover{border-color:#00ffcc;box-shadow:0 0 10px #00ffcc;transform:translateY(-2px);color:#00ffcc;}</style></head><body><h1>&#128194; $dirName</h1><a href='../index.html' class='back-btn'>&#11013; RETURN TO PARENT FOLDER</a><div class='grid'>"
        
        $items = Get-ChildItem -Path $dir.FullName | Where-Object { $_.Name -ne 'index.html' }
        foreach ($item in $items) {
            $icon = if ($item.PSIsContainer) { "&#128193;" } else { "&#128196;" }
            $link = if ($item.PSIsContainer) { "$($item.Name)/index.html" } else { "$($item.Name)" }
            $html += "<a href='$link'><div class='card'>$icon $($item.Name)</div></a>"
        }
        $html += "</div></body></html>"
        
        $outPath = Join-Path $dir.FullName "index.html"
        [System.IO.File]::WriteAllText($outPath, $html, $utf8)
        
        Build-UI $dir.FullName
    }
}

Build-UI "04_Short_Notes"

Write-Host "English and Hindi are fully restored in Short Notes!" -ForegroundColor Green