$utf8 = New-Object System.Text.UTF8Encoding $False
$subjects = @("Biology", "Chemistry", "Computer Applications", "English Language", "English Literature", "Geography", "Hindi", "History and Civics", "Maths", "Physics", "Speaking Skills")
$allSections = @("01_Nexus", "02_The_Cartel", "03_PYQs", "04_Short_Notes", "05_Cached", "06_Syllabus", "07_Specimens")

# Phase 1: Clone unified empty chapters ONLY to 04_Short_Notes
foreach ($sub in $subjects) {
    if ($sub -eq "Speaking Skills") { continue } # Excluded from Short Notes
    
    $allChapters = @()
    if (Test-Path "01_Nexus\$sub") { $allChapters += Get-ChildItem -Path "01_Nexus\$sub" -Directory | Select-Object -ExpandProperty Name }
    if (Test-Path "02_The_Cartel\$sub") { $allChapters += Get-ChildItem -Path "02_The_Cartel\$sub" -Directory | Select-Object -ExpandProperty Name }
    $allChapters = $allChapters | Select-Object -Unique

    $targetDir = "04_Short_Notes\$sub"
    if (!(Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }
    foreach ($chap in $allChapters) {
        $chapDir = "$targetDir\$chap"
        if (!(Test-Path $chapDir)) { New-Item -ItemType Directory -Path $chapDir | Out-Null }
    }
}

# Phase 2: Generate the Dark Mode UI for every folder
foreach ($sec in $allSections) {
    foreach ($sub in $subjects) {
        if ($sub -eq "Speaking Skills" -and $sec -ne "01_Nexus") { continue }
        $subPath = "$sec\$sub"
        if (Test-Path $subPath) {
            $html = "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'><title>$sub Chapters</title>"
            $html += "<style>body { background: #0a0a0a; color: #00ffcc; font-family: 'Courier New', Courier, monospace; text-align: center; margin: 0; padding: 40px; } h1 { font-size: 2.5em; text-shadow: 0 0 15px #00ffcc; margin-bottom: 20px; text-transform: uppercase; } .back-btn { display: inline-block; margin-bottom: 40px; padding: 10px 20px; background-color: #222; color: #fff; text-decoration: none; border-radius: 5px; border: 1px solid #444; transition: 0.3s; } .back-btn:hover { background-color: #00ffcc; color: #000; } .dashboard { display: flex; flex-wrap: wrap; justify-content: center; gap: 15px; max-width: 1200px; margin: 0 auto; } .card { background-color: #141414; border: 1px solid #333; border-radius: 8px; padding: 15px 20px; font-size: 1.1em; font-weight: bold; cursor: pointer; transition: all 0.3s; color: #fff; text-decoration: none; min-width: 250px; text-align: left; } .card:hover { border-color: #00ffcc; box-shadow: 0 0 10px #00ffcc; transform: translateY(-2px); color: #00ffcc; }</style>"
            $html += "</head><body><h1>📂 $sub</h1><a href='../index.html' class='back-btn'>⬅ RETURN TO SUBJECTS</a><div class='dashboard'>"
            
            $items = Get-ChildItem -Path $subPath | Where-Object { $_.Name -ne 'index.html' }
            foreach ($item in $items) {
                $icon = if ($item.PSIsContainer) { "📁" } else { "📄" }
                $html += "<a href='$($item.Name)' class='card'>$icon $($item.Name)</a>"
            }
            $html += "</div></body></html>"
            
            $outPath = Join-Path (Get-Location) "$subPath\index.html"
            [System.IO.File]::WriteAllText($outPath, $html, $utf8)
        }
    }
}
Write-Host "Links Repaired and Short Notes Expanded!" -ForegroundColor Green