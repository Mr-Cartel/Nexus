Add-Type -AssemblyName System.Windows.Forms

# 1. The Drop Zone (Select File)
$fileDialog = New-Object System.Windows.Forms.OpenFileDialog
$fileDialog.Filter = "Accepted Files|*.pdf;*.docx;*.jpg;*.jpeg;*.png"
$fileDialog.Title = "Select File for The Cartel Vault"
if ($fileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }
$sourceFile = $fileDialog.FileName

# 2. The Auto-Sorter (Select Vault, Subject, and Chapter)
$sections = @("01_Nexus", "02_The_Cartel", "03_PYQs", "04_Short_Notes", "05_Cached", "06_Syllabus", "07_Specimens")
$selectedSec = $sections | Out-GridView -Title "1. Which Vault?" -OutputMode Single
if (!$selectedSec) { exit }

$subjects = Get-ChildItem -Path $selectedSec -Directory | Select-Object -ExpandProperty Name
$selectedSub = $subjects | Out-GridView -Title "2. Which Subject in $selectedSec?" -OutputMode Single
if (!$selectedSub) { exit }

$chapters = Get-ChildItem -Path "$selectedSec\$selectedSub" -Directory | Select-Object -ExpandProperty Name
$selectedChap = $chapters | Out-GridView -Title "3. Which Chapter in $selectedSub?" -OutputMode Single
if (!$selectedChap) { exit }

# 3. Target Setup
$targetDir = "$selectedSec\$selectedSub\$selectedChap"
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile)
$ext = [System.IO.Path]::GetExtension($sourceFile).ToLower()
$targetPdf = Join-Path (Resolve-Path $targetDir).Path "$fileName.pdf"

Write-Host "Target Locked: $targetPdf" -ForegroundColor Cyan

# 4. Flawless PDF Converter (Ghost Mode)
if ($ext -eq ".pdf") {
    Copy-Item $sourceFile $targetPdf -Force
    Write-Host "PDF Copied Successfully." -ForegroundColor Green
}
elseif ($ext -match "\.(docx|jpg|jpeg|png)$") {
    Write-Host "Engaging Headless Conversion Engine..." -ForegroundColor Yellow
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false # Keeps Word completely hidden and safe
    
    if ($ext -eq ".docx") {
        $doc = $word.Documents.Open($sourceFile)
        $doc.SaveAs([ref]$targetPdf, [ref]17) # 17 is the code for PDF format
        $doc.Close()
    }
    else {
        # Packs Image into PDF flawlessly
        $doc = $word.Documents.Add()
        $shape = $doc.InlineShapes.AddPicture($sourceFile, $false, $true)
        $doc.SaveAs([ref]$targetPdf, [ref]17)
        $doc.Close([ref]0) # Closes without saving changes to Word
    }
    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
    Write-Host "Conversion Complete!" -ForegroundColor Green
}

# 5. Auto-Update the UI
Write-Host "Wiring UI for new file..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File unbreakable-engine.ps1 | Out-Null
Write-Host "UPLOAD SECURED!" -ForegroundColor Green
Start-Sleep -Seconds 2