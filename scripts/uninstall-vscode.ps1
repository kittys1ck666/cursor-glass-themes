#Requires -Version 5.1
param([switch]$Insiders)

$ErrorActionPreference = "Stop"

$ThemeDir = Join-Path $env:USERPROFILE ".vscode\glass-themes"
$SettingsPath = Join-Path $env:APPDATA "Code\User\settings.json"
$AppFolder = if ($Insiders) { "Microsoft VS Code Insiders" } else { "Microsoft VS Code" }
$WorkbenchHtml = Join-Path $env:LOCALAPPDATA "Programs\$AppFolder\resources\app\out\vs\code\electron-sandbox\workbench\workbench.html"
$ProductJson = Join-Path $env:LOCALAPPDATA "Programs\$AppFolder\resources\app\product.json"

Write-Host "`n==> Removing workbench patch" -ForegroundColor Cyan
if (Test-Path $WorkbenchHtml) {
    $html = Get-Content $WorkbenchHtml -Raw -Encoding UTF8
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', ''
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', ''
    [System.IO.File]::WriteAllText($WorkbenchHtml, $html, [System.Text.UTF8Encoding]::new($false))
    $hash = [Convert]::ToBase64String(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes($WorkbenchHtml))
    ).TrimEnd('=')
    $product = Get-Content $ProductJson -Raw -Encoding UTF8
    $product = $product -replace '"vs/code/electron-sandbox/workbench/workbench.html":\s*"[^"]+"', "`"vs/code/electron-sandbox/workbench/workbench.html`": `"$hash`""
    [System.IO.File]::WriteAllText($ProductJson, $product, [System.Text.UTF8Encoding]::new($false))
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
