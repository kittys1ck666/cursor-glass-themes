#Requires -Version 5.1
<#
.SYNOPSIS
  Install Cursor Glass theme (Agents window + WebGL marble).
.PARAMETER Theme
  Theme id from themes.json (abyss, sakura, noir, porcelain, aurora, ember, midnight-gold, neon-tokyo).
  If omitted, shows interactive picker.
#>
param(
    [string]$Theme,
    [switch]$SkipExtensions,
    [switch]$SkipWorkbenchPatch
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

$RepoRoot     = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $RepoRoot "themes.json"
$ThemeDir     = Join-Path $env:USERPROFILE ".cursor\cursor-abyss-glass"
$SettingsPath = Join-Path $env:APPDATA "Cursor\User\settings.json"
$CursorExe    = Join-Path $env:LOCALAPPDATA "Programs\cursor\Cursor.exe"
$WorkbenchHtml = Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app\out\vs\code\electron-sandbox\workbench\workbench.html"
$ProductJson   = Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app\product.json"
$ExtDir        = Join-Path $RepoRoot ".cache\extensions"

function Select-ThemeInteractive {
    param($ManifestObj)
    Write-Host "`n  Available themes:`n" -ForegroundColor White
    for ($i = 0; $i -lt $ManifestObj.themes.Count; $i++) {
        $t = $ManifestObj.themes[$i]
        $mode = if ($t.mode -eq "light") { "light" } else { "dark " }
        Write-Host ("  [{0,2}] {1,-16} [{2}]" -f ($i + 1), $t.id, $mode) -ForegroundColor Yellow
        Write-Host "       $($t.name) - $($t.description)" -ForegroundColor DarkGray
    }
    Write-Host ""
    $choice = Read-Host "Enter number or theme id (default: abyss)"
    if ([string]::IsNullOrWhiteSpace($choice)) { return "abyss" }
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $ManifestObj.themes.Count) { return $ManifestObj.themes[$idx].id }
    }
    return $choice.Trim().ToLower()
}

function Resolve-ThemeEntry {
    param([string]$Id, $ManifestObj)
    $entry = $ManifestObj.themes | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $entry) {
        $ids = ($ManifestObj.themes | ForEach-Object { $_.id }) -join ", "
        throw "Unknown theme '$Id'. Available: $ids"
    }
    return $entry
}

function To-FileUrl([string]$Path) {
    $p = (Resolve-Path $Path).Path.Replace('\', '/')
    if ($p -match '^[A-Za-z]:') { return "file:///$p" }
    return "file://$p"
}

function Merge-Settings {
    param([hashtable]$Patch)
    $dir = Split-Path $SettingsPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    if (Test-Path $SettingsPath) {
        $backup = "$SettingsPath.bak-glass-theme"
        Copy-Item $SettingsPath $backup -Force
    }

    if (Test-Path $SettingsPath) {
        $raw = Get-Content $SettingsPath -Raw -Encoding UTF8
        if ($raw.Trim()) {
            $obj = $raw | ConvertFrom-Json
        } else {
            $obj = New-Object PSObject
        }
    } else {
        $obj = New-Object PSObject
    }

    foreach ($key in $Patch.Keys) {
        $val = $Patch[$key]
        $prop = $obj.PSObject.Properties[$key]
        if ($prop) {
            $prop.Value = $val
        } else {
            $obj | Add-Member -NotePropertyName $key -NotePropertyValue $val -Force
        }
    }

    $json = $obj | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($SettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Install-ExtensionVsix {
    param([string]$Url, [string]$OutName)
    if (-not (Test-Path $CursorExe)) { throw "Cursor not found at $CursorExe" }
    New-Item -ItemType Directory -Force -Path $ExtDir | Out-Null
    $out = Join-Path $ExtDir $OutName
    if (-not (Test-Path $out)) {
        Write-Host "    Downloading $OutName ..."
        Invoke-WebRequest -Uri $Url -OutFile $out -UseBasicParsing
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $CursorExe --install-extension $out 2>$null | Out-Null
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($exit -ne 0) {
        Write-Warn "Extension install may have failed for $OutName. Install manually: $out"
    } else {
        Write-Ok "Installed $OutName"
    }
}

function Patch-Workbench {
    param([string]$CombinedCss, [string]$JsContent)

    if (-not (Test-Path $WorkbenchHtml)) { throw "workbench.html not found" }

    $indicatorPath = Join-Path $env:USERPROFILE ".cursor\extensions\be5invis.vscode-custom-css-7.4.0\src\statusbar.js"
    if (-not (Test-Path $indicatorPath)) {
        $found = Get-ChildItem (Join-Path $env:USERPROFILE ".cursor\extensions") -Filter "be5invis.vscode-custom-css-*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $indicatorPath = Join-Path $found.FullName "src\statusbar.js" }
    }
    if (-not (Test-Path $indicatorPath)) {
        Write-Warn "statusbar.js not found - run Enable Custom CSS and JS in Cursor after restart."
        return
    }

    $indicator = Get-Content $indicatorPath -Raw -Encoding UTF8
    $html = Get-Content $WorkbenchHtml -Raw -Encoding UTF8
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', ''
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', ''

    $id = [guid]::NewGuid().ToString()
    $inject = @"
<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID $id !! -->
<!-- !! VSCODE-CUSTOM-CSS-START !! -->
<script>$indicator</script>
<style>$CombinedCss</style>
<script>$JsContent</script>
<!-- !! VSCODE-CUSTOM-CSS-END !! -->

"@
    $html = $html -replace '</html>', "$inject</html>"
    [System.IO.File]::WriteAllText($WorkbenchHtml, $html, [System.Text.UTF8Encoding]::new($false))

    $hash = [Convert]::ToBase64String(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes($WorkbenchHtml))
    ).TrimEnd('=')

    $product = Get-Content $ProductJson -Raw -Encoding UTF8
    $product = $product -replace '"vs/code/electron-sandbox/workbench/workbench.html":\s*"[^"]+"', "`"vs/code/electron-sandbox/workbench/workbench.html`": `"$hash`""
    [System.IO.File]::WriteAllText($ProductJson, $product, [System.Text.UTF8Encoding]::new($false))
    Write-Ok "Patched workbench.html + checksum"
}

Write-Host @"

  Cursor Glass Themes - Installer
  Glass Agents window + animated marble background

"@ -ForegroundColor White

if (-not (Test-Path $ManifestPath)) { throw "themes.json not found at $ManifestPath" }
$Manifest = Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $Theme) { $Theme = Select-ThemeInteractive -ManifestObj $Manifest }
$entry = Resolve-ThemeEntry -Id $Theme -ManifestObj $Manifest

$PresetSrc  = Join-Path $RepoRoot ($entry.preset -replace '/', '\')
$BaseSrc    = Join-Path $RepoRoot "theme\glass-base.css"
$IdeSrc     = Join-Path $RepoRoot "theme\ide-agent.css"
$MarbleSrc  = Join-Path $RepoRoot "theme\marble.js"

if (-not (Test-Path $PresetSrc)) { throw "Preset not found: $PresetSrc" }

Write-Step "Installing theme: $($entry.name) ($($entry.id))"
Write-Ok $entry.description

Write-Step "Copying files to $ThemeDir"
New-Item -ItemType Directory -Force -Path (Join-Path $ThemeDir "presets") | Out-Null
Copy-Item $PresetSrc (Join-Path $ThemeDir "presets\$($entry.id).css") -Force
Copy-Item $BaseSrc (Join-Path $ThemeDir "glass-base.css") -Force
Copy-Item $IdeSrc (Join-Path $ThemeDir "ide-agent.css") -Force
Copy-Item $MarbleSrc (Join-Path $ThemeDir "marble.js") -Force
Get-ChildItem (Join-Path $RepoRoot "theme\presets\*.css") | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $ThemeDir "presets\$($_.Name)") -Force
}
@{ id = $entry.id; name = $entry.name; mode = $entry.mode } | ConvertTo-Json | Set-Content (Join-Path $ThemeDir "active-theme.json") -Encoding UTF8
Write-Ok "Theme files copied"

$PresetPath = Join-Path $ThemeDir "presets\$($entry.id).css"
$BasePath   = Join-Path $ThemeDir "glass-base.css"
$IdePath    = Join-Path $ThemeDir "ide-agent.css"
$JsPath     = Join-Path $ThemeDir "marble.js"
$BundlePath = Join-Path $ThemeDir "active-glass.css"

$combined = (Get-Content $PresetPath -Raw -Encoding UTF8) + "`n`n" + (Get-Content $BasePath -Raw -Encoding UTF8) + "`n`n" + (Get-Content $IdePath -Raw -Encoding UTF8)
[System.IO.File]::WriteAllText($BundlePath, $combined, [System.Text.UTF8Encoding]::new($false))

Write-Step "Updating Cursor settings"
$imports = @(
    (To-FileUrl $PresetPath),
    (To-FileUrl $BasePath),
    (To-FileUrl $IdePath),
    (To-FileUrl $JsPath)
)
$settingsPatch = @{
    "cursor.general.reduceTransparency" = $false
    "vscode_custom_css.imports"           = $imports
    "vscode_custom_css.statusbar"         = $true
}
if ($entry.mode -eq "light") {
    $settingsPatch["workbench.preferredLightColorTheme"] = $entry.cursorTheme
    $settingsPatch["window.autoDetectColorScheme"] = $false
} else {
    $settingsPatch["workbench.preferredDarkColorTheme"] = $entry.cursorTheme
}
Merge-Settings $settingsPatch
Write-Ok "settings.json updated (Cursor theme: $($entry.cursorTheme))"

if (-not $SkipExtensions) {
    Write-Step "Installing required extensions"
    Install-ExtensionVsix `
        -Url "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/be5invis/vsextensions/vscode-custom-css/7.4.0/vspackage" `
        -OutName "vscode-custom-css-7.4.0.vsix"
    Install-ExtensionVsix `
        -Url "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/RimuruChan/vsextensions/vscode-fix-checksums-next/1.4.0/vspackage" `
        -OutName "vscode-fix-checksums-next-1.4.0.vsix"
}

if (-not $SkipWorkbenchPatch) {
    Write-Step "Patching Cursor workbench"
    try {
        Patch-Workbench -CombinedCss $combined -JsContent (Get-Content $JsPath -Raw -Encoding UTF8)
    } catch {
        Write-Warn $_.Exception.Message
        Write-Warn "Run Cursor as Administrator, then: Enable Custom CSS and JS -> Fix Checksums: Apply"
    }
}

Write-Host @"

  Done! Theme: $($entry.name)

  Next steps:
    1. Fully quit and restart Cursor
    2. Open the Agents window (glass layout)
    3. Command Palette if needed: Enable Custom CSS and JS -> Fix Checksums: Apply
    4. Restart again

  Switch theme later:
    powershell -ExecutionPolicy Bypass -File "$($MyInvocation.MyCommand.Path)" -Theme $($entry.id)

  After Cursor updates, re-run the same command with your theme id.

"@ -ForegroundColor Green
