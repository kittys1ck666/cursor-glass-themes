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
$CursorAppDir = Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app"
$VsCodeDir    = Join-Path $CursorAppDir "out\vs\code"
$WorkbenchHtml = Join-Path $VsCodeDir "electron-sandbox\workbench\workbench.html"
$SandboxEsmHtml = Join-Path $VsCodeDir "electron-sandbox\workbench\workbench.esm.html"
$BrowserHtml  = Join-Path $VsCodeDir "electron-browser\workbench\workbench.html"
$ProductJson   = Join-Path $CursorAppDir "product.json"
$ExtDir        = Join-Path $RepoRoot ".cache\extensions"
$CustomCssWorkbenchPaths = @($WorkbenchHtml, $SandboxEsmHtml, $BrowserHtml)

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

function Get-WorkbenchColorCustomizations {
    param([string]$PresetCss, [string]$Mode)

    $base = if ($Mode -eq 'light') { '#f6f6f4' } else { '#191c22' }
    if ($PresetCss -match '--a-wb-surface:\s*(#[0-9a-fA-F]{6})') {
        $base = $matches[1]
    } elseif ($PresetCss -match '--a-bg:\s*(#[0-9a-fA-F]{6})') {
        $base = $matches[1]
    }

    $h = $base.TrimStart('#')
    function Alpha([string]$Hex, [string]$Suffix) { return "#$Hex$Suffix" }

    $widgetBg = if ($Mode -eq 'light') { Alpha $h 'ee' } else { Alpha $h 'dd' }
    $widgetBgSolid = if ($Mode -eq 'light') { Alpha $h 'f5' } else { Alpha $h 'ee' }

    return @{
        'editor.background'                   = Alpha $h '00'
        'sideBar.background'                  = Alpha $h '00'
        'activityBar.background'              = Alpha $h '00'
        'panel.background'                    = Alpha $h '00'
        'editorGroupHeader.tabsBackground'    = Alpha $h '00'
        'editorGroupHeader.noTabsBackground'  = Alpha $h '00'
        'statusBar.background'                = Alpha $h '00'
        'titleBar.activeBackground'           = Alpha $h '00'
        'titleBar.inactiveBackground'         = Alpha $h '00'
        'tab.activeBackground'                = Alpha $h '30'
        'tab.inactiveBackground'              = Alpha $h '15'
        'tab.hoverBackground'                 = Alpha $h '30'
        'tab.unfocusedHoverBackground'        = Alpha $h '20'
        'sideBarSectionHeader.background'     = Alpha $h '20'
        'list.activeSelectionBackground'      = Alpha $h '40'
        'list.inactiveSelectionBackground'    = Alpha $h '25'
        'list.hoverBackground'                = Alpha $h '25'
        'list.focusBackground'                = Alpha $h '40'
        'editorWidget.background'             = $widgetBg
        'editorSuggestWidget.background'      = $widgetBgSolid
        'editorHoverWidget.background'        = $widgetBg
        'peekViewEditor.background'           = Alpha $h 'cc'
        'peekViewResult.background'           = Alpha $h 'cc'
        'peekViewTitle.background'            = $widgetBg
        'input.background'                    = Alpha $h '55'
        'dropdown.background'                 = $widgetBg
        'menu.background'                     = $widgetBgSolid
        'notifications.background'            = $widgetBgSolid
        'debugToolBar.background'             = $widgetBg
        'breadcrumb.background'               = Alpha $h '00'
        'breadcrumbPicker.background'         = $widgetBg
        'terminal.background'                 = Alpha $h '00'
        'terminal.foreground'                 = if ($Mode -eq 'light') { '#1f1018' } else { '#e8eef8' }
        'terminal.ansiBlack'                  = if ($Mode -eq 'light') { '#2a2a2a' } else { '#0b1220' }
        'terminal.ansiRed'                    = '#ff6b7a'
        'terminal.ansiGreen'                  = if ($Mode -eq 'light') { '#1a7f4b' } else { '#4ae878' }
        'terminal.ansiYellow'                 = '#f0c674'
        'terminal.ansiBlue'                   = if ($Mode -eq 'light') { '#2f6fed' } else { '#7ec8ff' }
        'terminal.ansiMagenta'                = '#c792ea'
        'terminal.ansiCyan'                   = '#7fdbca'
        'terminal.ansiWhite'                  = if ($Mode -eq 'light') { '#1f1018' } else { '#e8eef8' }
        'terminal.ansiBrightBlack'            = '#6b7a90'
        'terminal.ansiBrightRed'              = '#ff8a96'
        'terminal.ansiBrightGreen'            = '#7dffb0'
        'terminal.ansiBrightYellow'           = '#ffe08a'
        'terminal.ansiBrightBlue'             = '#a8dcff'
        'terminal.ansiBrightMagenta'          = '#e0b0ff'
        'terminal.ansiBrightCyan'             = '#a8fff0'
        'terminal.ansiBrightWhite'            = '#ffffff'
        'editorGroup.border'                  = Alpha $h '00'
        'editorGroupHeader.tabsBorder'        = Alpha $h '00'
        'tab.border'                          = Alpha $h '00'
        'tab.activeBorder'                    = Alpha $h '00'
        'tab.unfocusedActiveBorder'           = Alpha $h '00'
        'panel.border'                        = Alpha $h '00'
        'sideBar.border'                      = Alpha $h '00'
        'activityBar.border'                  = Alpha $h '00'
        'statusBar.border'                    = Alpha $h '00'
        'titleBar.border'                     = Alpha $h '00'
    }
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
    if (-not (Test-Path $CursorExe)) {
        Write-Warn "Cursor.exe not found — skip extension $OutName (theme still works via workbench patch)"
        return
    }
    New-Item -ItemType Directory -Force -Path $ExtDir | Out-Null
    $out = Join-Path $ExtDir $OutName
    if (-not (Test-Path $out)) {
        Write-Host "    Downloading $OutName ..."
        Invoke-WebRequest -Uri $Url -OutFile $out -UseBasicParsing
    }
    # Prefer CLI if present
    $cli = Join-Path (Split-Path $CursorExe -Parent) "resources\app\bin\cursor.cmd"
    if (-not (Test-Path $cli)) { $cli = $CursorExe }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $outText = & $cli --install-extension $out --force 2>&1 | Out-String
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($outText -match 'successfully installed|already installed|is already installed') {
        Write-Ok "Installed $OutName"
    } elseif ($exit -ne 0) {
        Write-Warn "Could not auto-install $OutName (optional). Theme still works via workbench patch."
    } else {
        Write-Ok "Extension present: $OutName"
    }
}

function Get-PatchIndicator {
    $bundled = Join-Path $RepoRoot "theme\patch-indicator.js"
    if (Test-Path $bundled) { return (Get-Content $bundled -Raw -Encoding UTF8) }
    # Fallback: extension statusbar if user already has Custom CSS
    $found = Get-ChildItem (Join-Path $env:USERPROFILE ".cursor\extensions") -Filter "be5invis.vscode-custom-css-*" -Directory -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($found) {
        $p = Join-Path $found.FullName "src\statusbar.js"
        if (Test-Path $p) { return (Get-Content $p -Raw -Encoding UTF8) }
    }
    return "/* glass themes indicator unavailable */"
}

function Test-WorkbenchPatched {
    param([string]$Path)
    return (Test-Path $Path) -and ((Get-Content $Path -Raw -Encoding UTF8) -match 'VSCODE-CUSTOM-CSS-START')
}

function Patch-Workbench {
    param([string]$CombinedCss, [string]$JsContent)

    $templatePaths = @($WorkbenchHtml, $SandboxEsmHtml, $BrowserHtml)
    if (-not ($templatePaths | Where-Object { $_ -and (Test-Path $_) })) {
        throw "workbench.html not found under $VsCodeDir"
    }

    $indicator = Get-PatchIndicator

    # Prefer pristine backup when available
    $html = $null
    foreach ($p in $templatePaths) {
        if (-not $p) { continue }
        $dir = Split-Path $p -Parent
        if (-not (Test-Path $dir)) { continue }
        $bak = Get-ChildItem $dir -Filter "workbench.*.bak-custom-css" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($bak) {
            $raw = Get-Content $bak.FullName -Raw -Encoding UTF8
            if ($raw -notmatch 'VSCODE-CUSTOM-CSS-START') {
                Write-Ok "Using pre-patch backup: $($bak.Name)"
                $html = $raw
                break
            }
        }
    }
    if (-not $html) {
        foreach ($p in $templatePaths) {
            if ($p -and (Test-Path $p)) {
                $html = Get-Content $p -Raw -Encoding UTF8
                break
            }
        }
    }
    if (-not $html) { throw "workbench.html template not found" }

    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', ''
    $html = $html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', ''
    $html = $html -replace '(?s)<meta\s+http-equiv="Content-Security-Policy"[\s\S]*?/>', ''

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

    foreach ($target in ($CustomCssWorkbenchPaths | Select-Object -Unique)) {
        if (-not $target) { continue }
        $targetDir = Split-Path $target -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }
        [System.IO.File]::WriteAllText($target, $html, [System.Text.UTF8Encoding]::new($false))
        Write-Ok "Patched $target"

        $hash = [Convert]::ToBase64String(
            [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes($target))
        ).TrimEnd('=')
        $rel = $target.Substring($CursorAppDir.Length).TrimStart('\').Replace('\', '/')
        $key = if ($rel -match '^out/(.+)$') { $matches[1] } else { $rel }
        $product = Get-Content $ProductJson -Raw -Encoding UTF8
        $escapedKey = [regex]::Escape($key)
        if ($product -match "`"$escapedKey`":\s*`"[^`"]+`"") {
            $product = $product -replace "`"$escapedKey`":\s*`"[^`"]+`"", "`"$key`": `"$hash`""
        } else {
            $product = $product -replace '("checksums"\s*:\s*\{)', "`$1`n`t`t`"$key`": `"$hash`","
        }
        [System.IO.File]::WriteAllText($ProductJson, $product, [System.Text.UTF8Encoding]::new($false))
    }
    Write-Ok "Patched workbench mirrors + checksums (no extension required)"
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
$WbSrc      = Join-Path $RepoRoot "theme\ide-workbench.css"
$MarbleSrc  = Join-Path $RepoRoot "theme\marble.js"
$IndicatorSrc = Join-Path $RepoRoot "theme\patch-indicator.js"

if (-not (Test-Path $PresetSrc)) { throw "Preset not found: $PresetSrc" }

Write-Step "Installing theme: $($entry.name) ($($entry.id))"
Write-Ok $entry.description

Write-Step "Copying files to $ThemeDir"
New-Item -ItemType Directory -Force -Path (Join-Path $ThemeDir "presets") | Out-Null
Copy-Item $PresetSrc (Join-Path $ThemeDir "presets\$($entry.id).css") -Force
Copy-Item $BaseSrc (Join-Path $ThemeDir "glass-base.css") -Force
Copy-Item $IdeSrc (Join-Path $ThemeDir "ide-agent.css") -Force
Copy-Item $WbSrc (Join-Path $ThemeDir "ide-workbench.css") -Force
Copy-Item $MarbleSrc (Join-Path $ThemeDir "marble.js") -Force
if (Test-Path $IndicatorSrc) { Copy-Item $IndicatorSrc (Join-Path $ThemeDir "patch-indicator.js") -Force }
Get-ChildItem (Join-Path $RepoRoot "theme\presets\*.css") | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $ThemeDir "presets\$($_.Name)") -Force
}
@{ id = $entry.id; name = $entry.name; mode = $entry.mode } | ConvertTo-Json | Set-Content (Join-Path $ThemeDir "active-theme.json") -Encoding UTF8
Write-Ok "Theme files copied"

$PresetPath = Join-Path $ThemeDir "presets\$($entry.id).css"
$BasePath   = Join-Path $ThemeDir "glass-base.css"
$IdePath    = Join-Path $ThemeDir "ide-agent.css"
$WbPath     = Join-Path $ThemeDir "ide-workbench.css"
$JsPath     = Join-Path $ThemeDir "marble.js"
$BundlePath = Join-Path $ThemeDir "active-glass.css"

$presetRaw = Get-Content $PresetPath -Raw -Encoding UTF8
$combined = $presetRaw + "`n`n" + (Get-Content $BasePath -Raw -Encoding UTF8) + "`n`n" + (Get-Content $IdePath -Raw -Encoding UTF8) + "`n`n" + (Get-Content $WbPath -Raw -Encoding UTF8)
[System.IO.File]::WriteAllText($BundlePath, $combined, [System.Text.UTF8Encoding]::new($false))

Write-Step "Updating Cursor settings"
$imports = @(
    (To-FileUrl $PresetPath),
    (To-FileUrl $BasePath),
    (To-FileUrl $IdePath),
    (To-FileUrl $WbPath),
    (To-FileUrl $JsPath)
)
$settingsPatch = @{
    "cursor.general.reduceTransparency" = $false
    "vscode_custom_css.imports"           = $imports
    "vscode_custom_css.statusbar"         = $true
    "workbench.colorTheme"                = $entry.cursorTheme
    "workbench.colorCustomizations"       = (Get-WorkbenchColorCustomizations -PresetCss $presetRaw -Mode $entry.mode)
    "window.titleBarStyle"                = "custom"
}
if ($entry.mode -eq "light") {
    $settingsPatch["workbench.preferredLightColorTheme"] = $entry.cursorTheme
    $settingsPatch["workbench.preferredDarkColorTheme"] = $entry.cursorTheme
    $settingsPatch["window.autoDetectColorScheme"] = $false
} else {
    $settingsPatch["workbench.preferredDarkColorTheme"] = $entry.cursorTheme
    $settingsPatch["workbench.preferredLightColorTheme"] = $entry.cursorTheme
}
Merge-Settings $settingsPatch
Write-Ok "settings.json updated (Cursor theme: $($entry.cursorTheme))"

$patched = $false
if (-not $SkipWorkbenchPatch) {
    Write-Step "Patching Cursor workbench (no extensions required)"
    try {
        Patch-Workbench -CombinedCss $combined -JsContent (Get-Content $JsPath -Raw -Encoding UTF8)
        $patched = (Test-WorkbenchPatched -Path $WorkbenchHtml)
    } catch {
        Write-Warn $_.Exception.Message
        Write-Warn "Close Cursor completely and re-run this installer as Administrator."
    }
}

if (-not $SkipExtensions) {
    Write-Step "Auto-installing optional helper extensions"
    Install-ExtensionVsix `
        -Url "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/be5invis/vsextensions/vscode-custom-css/7.4.0/vspackage" `
        -OutName "vscode-custom-css-7.4.0.vsix"
    Install-ExtensionVsix `
        -Url "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/RimuruChan/vsextensions/vscode-fix-checksums-next/1.4.0/vspackage" `
        -OutName "vscode-fix-checksums-next-1.4.0.vsix"
}

Write-Host ""
Write-Host "  Done! Theme: $($entry.name)" -ForegroundColor Green
Write-Host ""
if ($patched) {
    Write-Host "  Next steps (only these):" -ForegroundColor Green
    Write-Host "    1. Fully quit Cursor (File → Exit)" -ForegroundColor Green
    Write-Host "    2. Start Cursor again" -ForegroundColor Green
    Write-Host ""
    Write-Host "  No 'Enable Custom CSS' needed — workbench is already patched." -ForegroundColor DarkGreen
    Write-Host "  If Cursor warns about installation integrity:" -ForegroundColor DarkYellow
    Write-Host "    Ctrl+Shift+P → Fix Checksums: Apply → restart once more" -ForegroundColor DarkYellow
} else {
    Write-Host "  Patch incomplete. Close Cursor, run PowerShell as Administrator, then:" -ForegroundColor Yellow
    Write-Host "    powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Theme $($entry.id)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Switch theme later:" -ForegroundColor Green
Write-Host "    powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Theme sakura" -ForegroundColor Green
Write-Host ""
