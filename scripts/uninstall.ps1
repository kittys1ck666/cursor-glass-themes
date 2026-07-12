#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$ThemeDir = Join-Path $env:USERPROFILE ".cursor\cursor-abyss-glass"
$SettingsPath = Join-Path $env:APPDATA "Cursor\User\settings.json"
$BackupPath = "$SettingsPath.bak-glass-theme"
$WorkbenchHtml = Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app\out\vs\code\electron-sandbox\workbench\workbench.html"
$ProductJson   = Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app\product.json"

$GlassKeys = @(
    'vscode_custom_css.imports',
    'vscode_custom_css.statusbar',
    'cursor.general.reduceTransparency',
    'workbench.colorCustomizations',
    'workbench.preferredLightColorTheme',
    'workbench.preferredDarkColorTheme',
    'window.autoDetectColorScheme'
)

Write-Host "`n==> Removing workbench patch" -ForegroundColor Cyan
if (Test-Path $WorkbenchHtml) {
    $html = Get-Content $WorkbenchHtml -Raw -Encoding UTF8
    if ($html -match 'VSCODE-CUSTOM-CSS-START') {
        $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', ''
        $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', ''
        [System.IO.File]::WriteAllText($WorkbenchHtml, $html, [System.Text.UTF8Encoding]::new($false))

        if (Test-Path $ProductJson) {
            $hash = [Convert]::ToBase64String(
                [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes($WorkbenchHtml))
            ).TrimEnd('=')
            $product = Get-Content $ProductJson -Raw -Encoding UTF8
            $product = $product -replace '"vs/code/electron-sandbox/workbench/workbench.html":\s*"[^"]+"', "`"vs/code/electron-sandbox/workbench/workbench.html`": `"$hash`""
            [System.IO.File]::WriteAllText($ProductJson, $product, [System.Text.UTF8Encoding]::new($false))
        }
        Write-Host "    workbench.html restored" -ForegroundColor Green
    } else {
        Write-Host "    no glass patch found" -ForegroundColor Yellow
    }
}

Write-Host "`n==> Cleaning settings.json" -ForegroundColor Cyan
if (Test-Path $BackupPath) {
    Copy-Item $BackupPath $SettingsPath -Force
    Write-Host "    Restored settings from settings.json.bak-glass-theme" -ForegroundColor Green
} elseif (Test-Path $SettingsPath) {
    $obj = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($key in $GlassKeys) {
        $p = $obj.PSObject.Properties[$key]
        if ($p) { $obj.PSObject.Properties.Remove($key) }
    }
    $json = $obj | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($SettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "    Glass settings keys removed (no backup found)" -ForegroundColor Green
}

Write-Host "`n==> Removing theme files" -ForegroundColor Cyan
if (Test-Path $ThemeDir) {
    Remove-Item $ThemeDir -Recurse -Force
    Write-Host "    $ThemeDir removed" -ForegroundColor Green
}

Write-Host "`nRestart Cursor. Backup kept at: $BackupPath`n" -ForegroundColor Yellow
