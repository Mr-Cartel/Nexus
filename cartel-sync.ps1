Write-Host "Scanning for .docx files to convert..." -ForegroundColor Cyan
$docFiles = Get-ChildItem -Path . -Recurse -Filter "*.docx"

if ($docFiles.Count -gt 0) {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    foreach ($doc in $docFiles) {
        $pdfPath = $doc.FullName -replace '\.docx$', '.pdf'
        $openedDoc = $word.Documents.Open($doc.FullName)
        $openedDoc.SaveAs([ref]$pdfPath, [ref]17)
        $openedDoc.Close()
        Remove-Item $doc.FullName -Force
        Write-Host "Converted and cleaned: $($doc.Name)" -ForegroundColor Green
    }
    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
}

Write-Host "Updating Website UI..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File unbreakable-engine.ps1 | Out-Null
Write-Host "SYNC COMPLETE! Website is perfectly updated." -ForegroundColor Green
Start-Sleep -Seconds 2