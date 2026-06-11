#Requires -Version 5.1
param([switch]$Insiders)

$ErrorActionPreference = "Stop"

$ThemeDir = Join-Path $env:USERPROFILE ".vscode\glass-themes"
$SettingsPath = Join-Path $env:APPDATA "Code\User\settings.json"
$AppFolder = if ($Insiders) { "Microsoft VS Code Insiders" } else { "Microsoft VS Code" }

function Resolve-VSCodePaths {
    param([string]$FolderName)
    $candidates = @(
        Join-Path $env:LOCALAPPDATA "Programs\$FolderName"
        (Join-Path ${env:ProgramFiles} $FolderName)
        (Join-Path ${env:ProgramFiles(x86)} $FolderName)
    ) | Where-Object { Test-Path $_ }
    foreach ($root in $candidates) {
        $product = Get-ChildItem $root -Recurse -Filter "product.json" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]resources[\\/]app[\\/]product\.json$' } |
            Select-Object -First 1
        if (-not $product) { continue }
        $workbench = Get-ChildItem $product.Directory.FullName -Recurse -Filter "workbench.html" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]workbench[\\/]workbench\.html$' } |
            Select-Object -First 1
        if ($workbench) {
            return @{ WorkbenchHtml = $workbench.FullName; ProductJson = $product.FullName }
        }
    }
    return $null
}

$vscodePaths = Resolve-VSCodePaths -FolderName $AppFolder
$WorkbenchHtml = if ($vscodePaths) { $vscodePaths.WorkbenchHtml } else { $null }
$ProductJson = if ($vscodePaths) { $vscodePaths.ProductJson } else { $null }

function Get-RelativePathCompat {
    param([string]$FromDir, [string]$ToPath)
    $from = $FromDir.TrimEnd('\') + '\'
    $fromUri = New-Object System.Uri $from
    $toUri = New-Object System.Uri ((Resolve-Path $ToPath).Path)
    return [Uri]::UnescapeDataString($fromUri.MakeRelativeUri($toUri).ToString()).Replace('\', '/')
}

function Update-ProductJsonChecksum {
    param([string]$ProductJsonPath, [string]$WorkbenchHtmlPath)
    $hash = [Convert]::ToBase64String(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes($WorkbenchHtmlPath))
    ).TrimEnd('=')
    $appDir = Split-Path $ProductJsonPath -Parent
    $rel = Get-RelativePathCompat -FromDir $appDir -ToPath $WorkbenchHtmlPath
    $key = if ($rel -match '^out/(.+)$') { $matches[1] } else { $rel }
    $product = Get-Content $ProductJsonPath -Raw -Encoding UTF8
    $escapedKey = [regex]::Escape($key)
    if ($product -match "`"$escapedKey`":\s*`"[^`"]+`"") {
        $product = $product -replace "`"$escapedKey`":\s*`"[^`"]+`"", "`"$key`": `"$hash`""
    } else {
        $product = $product -replace '"vs/code/[^"]+/workbench/workbench\.html":\s*"[^"]+"', "`"$key`": `"$hash`""
    }
    [System.IO.File]::WriteAllText($ProductJsonPath, $product, [System.Text.UTF8Encoding]::new($false))
}

Write-Host "`n==> Removing workbench patch" -ForegroundColor Cyan
if ($WorkbenchHtml -and (Test-Path $WorkbenchHtml)) {
    $html = Get-Content $WorkbenchHtml -Raw -Encoding UTF8
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', ''
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', ''
    [System.IO.File]::WriteAllText($WorkbenchHtml, $html, [System.Text.UTF8Encoding]::new($false))
    if ($ProductJson -and (Test-Path $ProductJson)) {
        Update-ProductJsonChecksum -ProductJsonPath $ProductJson -WorkbenchHtmlPath $WorkbenchHtml
    }
    Write-Host "    workbench.html restored" -ForegroundColor Green
}

Write-Host "`n==> Cleaning settings.json" -ForegroundColor Cyan
if (Test-Path $SettingsPath) {
    $obj = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    @(
        'vscode_custom_css.imports',
        'vscode_custom_css.statusbar',
        'workbench.colorCustomizations',
        'workbench.colorTheme',
        'window.titleBarStyle'
    ) | ForEach-Object {
        $p = $obj.PSObject.Properties[$_]
        if ($p) { $p.Value = $null; $obj.PSObject.Properties.Remove($_) }
    }
    $json = $obj | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($SettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "    Custom CSS settings removed" -ForegroundColor Green
}

Write-Host "`n==> Removing theme files" -ForegroundColor Cyan
if (Test-Path $ThemeDir) {
    Remove-Item $ThemeDir -Recurse -Force
    Write-Host "    $ThemeDir removed" -ForegroundColor Green
}

Write-Host "`nRestart VS Code. Restore settings from settings.json.bak-glass-theme if needed.`n" -ForegroundColor Yellow
