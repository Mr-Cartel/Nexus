$sections = @("01_Nexus", "02_The_Cartel", "03_PYQs", "04_Short_Notes", "05_Cached", "06_Syllabus", "07_Specimens")
foreach ($sec in $sections) {
    $file = "$sec\index.html"
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        $content = $content.Replace('<a href="Blueprint"><div class="card">📐 Blueprint</div></a>', '')
        if ($sec -ne "01_Nexus") {
            $content = $content.Replace('<a href="Speaking Skills"><div class="card">🗣️ Speaking Skills</div></a>', '')
        }
        Set-Content -Path $file -Value $content -Encoding UTF8
    }
}
Write-Host "Ghost buttons vaporized!" -ForegroundColor Green