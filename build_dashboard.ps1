$vaultPath = "C:\Project Nexus PDF version"
$htmlFile = "$vaultPath\index.html"

$head = @"
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Binary Cartel Vault</title><style>body{font-family:Segoe UI,sans-serif;background-color:#121212;color:#ffffff;padding:20px;line-height:1.6}h1{border-bottom:2px solid #00ffcc;padding-bottom:10px;color:#00ffcc}details{margin:10px 0 10px 20px;padding:5px;background:#1e1e1e;border-radius:5px;border-left:4px solid #00ffcc}summary{font-size:18px;font-weight:bold;cursor:pointer;outline:none;padding:5px}a{color:#4da6ff;text-decoration:none;display:block;margin:5px 0 5px 20px}a:hover{color:#00ffcc}</style></head><body><h1>Binary Cartel Vault</h1>
"@

Set-Content -Path $htmlFile -Value $head -Encoding UTF8

function Build-Directory ($path) {
    $folders = Get-ChildItem -Path $path -Directory | Sort-Object Name
    $files = Get-ChildItem -Path $path -File | Sort-Object Name
    
    foreach ($item in $folders) {
        $relPath = $item.FullName.Substring($vaultPath.Length).Replace("\", "/").TrimStart("/")
        Add-Content -Path $htmlFile -Value "<details><summary>[ $($item.Name) ]</summary>" -Encoding UTF8
        Build-Directory $item.FullName
        Add-Content -Path $htmlFile -Value "</details>" -Encoding UTF8
    }
    
    foreach ($item in $files) {
        if ($item.Name -match "^\.|index\.html|.*\.bat|.*\.ps1") { continue }
        $relPath = $item.FullName.Substring($vaultPath.Length).Replace("\", "/").TrimStart("/")
        Add-Content -Path $htmlFile -Value "<a href='./$relPath' target='_blank'>$($item.Name)</a>" -Encoding UTF8
    }
}

Build-Directory $vaultPath
Add-Content -Path $htmlFile -Value "</body></html>" -Encoding UTF8