#Requires -Version 5.1
<#
.SYNOPSIS
  Install Glass Themes for Microsoft VS Code (workbench glass + WebGL marble).
.PARAMETER Theme
  Theme id from themes.json (abyss, sakura, noir, ...).
.PARAMETER Insiders
  Target VS Code Insiders instead of stable.
#>
param(
    [string]$Theme,
    [switch]$Insiders,
    [switch]$SkipExtensions,
    [switch]$SkipWorkbenchPatch
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

$RepoRoot     = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $RepoRoot "themes.json"
$ThemeDir     = Join-Path $env:USERPROFILE ".vscode\glass-themes"
$SettingsPath = Join-Path $env:APPDATA "Code\User\settings.json"
$AppFolder    = if ($Insiders) { "Microsoft VS Code Insiders" } else { "Microsoft VS Code" }
$ExtDir        = Join-Path $RepoRoot ".cache\extensions"
$ExtRoot       = Join-Path $env:USERPROFILE ".vscode\extensions"
$RequiredCssExtId = "be5invis.vscode-custom-css"

function Get-CustomCssMirrorPaths {
    param([string]$VsCodeDir)
    $sandboxDir = Join-Path $VsCodeDir "electron-sandbox\workbench"
    return @(
        (Join-Path $sandboxDir "workbench.html"),
        (Join-Path $sandboxDir "workbench.esm.html"),
        (Join-Path $VsCodeDir "electron-browser\workbench\workbench.html")
    )
}

function Clear-WorkbenchPatches {
    param([string]$Html)
    $Html = $Html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', ''
    $Html = $Html -replace '(?s)<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', ''
    return $Html
}

function Strip-WorkbenchCsp {
    param([string]$Html)
    return $Html -replace '(?s)<meta\s+http-equiv="Content-Security-Policy"[\s\S]*?/>', ''
}

function Get-PristineWorkbenchHtml {
    param([string[]]$Paths)
    foreach ($p in $Paths) {
        if (-not $p) { continue }
        $dir = Split-Path $p -Parent
        $bak = Get-ChildItem $dir -Filter "workbench.*.bak-custom-css" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($bak) {
            $raw = Get-Content $bak.FullName -Raw -Encoding UTF8
            if ($raw -notmatch 'VSCODE-CUSTOM-CSS-START') {
                Write-Ok "Using pre-patch backup: $($bak.Name)"
                return (Clear-WorkbenchPatches $raw)
            }
        }
    }
    foreach ($p in $Paths) {
        if ($p -and (Test-Path $p)) {
            return (Clear-WorkbenchPatches (Get-Content $p -Raw -Encoding UTF8))
        }
    }
    throw "workbench.html template not found"
}

function Test-CustomCssExtension {
    $correct = @(Get-ChildItem $ExtRoot -Filter "$RequiredCssExtId-*" -Directory -ErrorAction SilentlyContinue)
    $wrong = @(Get-ChildItem $ExtRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '(?i)custom[-_.]?css|css[-_.]?loader' -and $_.Name -notmatch "^$([regex]::Escape($RequiredCssExtId))"
    })
    return @{
        Correct = $correct | Select-Object -First 1
        Wrong   = $wrong
    }
}

function Resolve-VSCodePaths {
    param([string]$FolderName)
    $candidates = @(
        Join-Path $env:LOCALAPPDATA "Programs\$FolderName"
        (Join-Path ${env:ProgramFiles} $FolderName)
        (Join-Path ${env:ProgramFiles(x86)} $FolderName)
    ) | Where-Object { Test-Path $_ }

    foreach ($root in $candidates) {
        $exe = Join-Path $root "Code.exe"
        if (-not (Test-Path $exe)) { continue }

        $product = Get-ChildItem $root -Recurse -Filter "product.json" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]resources[\\/]app[\\/]product\.json$' } |
            Select-Object -First 1
        if (-not $product) { continue }

        $appDir = $product.Directory.FullName
        $vsCodeDir = Join-Path $appDir "out\vs\code"
        $browserWb = Join-Path $vsCodeDir "electron-browser\workbench\workbench.html"
        $sandboxWb = Join-Path $vsCodeDir "electron-sandbox\workbench\workbench.html"
        $sandboxEsmWb = Join-Path $vsCodeDir "electron-sandbox\workbench\workbench.esm.html"

        # VS Code + be5invis load electron-sandbox/workbench/workbench.html (not browser).
        $canonical = $null
        foreach ($candidate in @($sandboxWb, $sandboxEsmWb, $browserWb)) {
            if (Test-Path $candidate) { $canonical = $candidate; break }
        }
        if (-not $canonical) {
            $workbench = Get-ChildItem $appDir -Recurse -Filter "workbench.html" -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '[\\/]workbench[\\/]workbench\.html$' } |
                Select-Object -First 1
            if (-not $workbench) { continue }
            $canonical = $workbench.FullName
        }

        $customCssPaths = Get-CustomCssMirrorPaths -VsCodeDir $vsCodeDir
        $customCssWb = $null
        foreach ($candidate in @($sandboxWb, $sandboxEsmWb)) {
            if (Test-Path $candidate) { $customCssWb = $candidate; break }
        }
        if (-not $customCssWb) { $customCssWb = $sandboxWb }

        return @{
            CodeExe                  = $exe
            WorkbenchHtml            = $canonical
            CustomCssWorkbenchHtml   = $customCssWb
            CustomCssWorkbenchPaths  = $customCssPaths
            SandboxWorkbenchHtml     = $sandboxWb
            SandboxEsmWorkbenchHtml  = $sandboxEsmWb
            VsCodeDir                = $vsCodeDir
            ProductJson              = $product.FullName
            InstallRoot              = $root
        }
    }
    return $null
}

$vscodePaths = Resolve-VSCodePaths -FolderName $AppFolder
if (-not $vscodePaths) {
    throw "VS Code not found. Install $AppFolder or pass -Insiders for Insiders build."
}
$CodeExe                = $vscodePaths.CodeExe
$WorkbenchHtml          = $vscodePaths.WorkbenchHtml
$CustomCssWorkbenchHtml = $vscodePaths.CustomCssWorkbenchHtml
$CustomCssWorkbenchPaths = $vscodePaths.CustomCssWorkbenchPaths
$ProductJson            = $vscodePaths.ProductJson

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
    if ($PresetCss -match '--a-wb-surface:\s*(#[0-9a-fA-F]{6})') { $base = $matches[1] }
    elseif ($PresetCss -match '--a-bg:\s*(#[0-9a-fA-F]{6})') { $base = $matches[1] }
    $h = $base.TrimStart('#')
    function Alpha([string]$Hex, [string]$Suffix) { return "#$Hex$Suffix" }
    $widgetBg = if ($Mode -eq 'light') { Alpha $h 'ee' } else { Alpha $h 'dd' }
    $widgetBgSolid = if ($Mode -eq 'light') { Alpha $h 'f5' } else { Alpha $h 'ee' }
    return @{
        'editor.background' = Alpha $h '00'
        'sideBar.background' = Alpha $h '00'
        'activityBar.background' = Alpha $h '00'
        'panel.background' = Alpha $h '00'
        'editorGroupHeader.tabsBackground' = Alpha $h '00'
        'editorGroupHeader.noTabsBackground' = Alpha $h '00'
        'statusBar.background' = Alpha $h '00'
        'titleBar.activeBackground' = Alpha $h '00'
        'titleBar.inactiveBackground' = Alpha $h '00'
        'tab.activeBackground' = Alpha $h '30'
        'tab.inactiveBackground' = Alpha $h '15'
        'tab.hoverBackground' = Alpha $h '30'
        'tab.unfocusedHoverBackground' = Alpha $h '20'
        'sideBarSectionHeader.background' = Alpha $h '20'
        'list.activeSelectionBackground' = Alpha $h '40'
        'list.inactiveSelectionBackground' = Alpha $h '25'
        'list.hoverBackground' = Alpha $h '25'
        'list.focusBackground' = Alpha $h '40'
        'editorWidget.background' = $widgetBg
        'editorSuggestWidget.background' = $widgetBgSolid
        'editorHoverWidget.background' = $widgetBg
        'peekViewEditor.background' = Alpha $h 'cc'
        'peekViewResult.background' = Alpha $h 'cc'
        'peekViewTitle.background' = $widgetBg
        'input.background' = Alpha $h '55'
        'dropdown.background' = $widgetBg
        'menu.background' = $widgetBgSolid
        'notifications.background' = $widgetBgSolid
        'debugToolBar.background' = $widgetBg
        'breadcrumb.background' = Alpha $h '00'
        'breadcrumbPicker.background' = $widgetBg
        'terminal.background' = Alpha $h '00'
        'editorGroup.border' = Alpha $h '00'
        'editorGroupHeader.tabsBorder' = Alpha $h '00'
        'tab.border' = Alpha $h '00'
        'tab.activeBorder' = Alpha $h '00'
        'tab.unfocusedActiveBorder' = Alpha $h '00'
        'panel.border' = Alpha $h '00'
        'sideBar.border' = Alpha $h '00'
        'activityBar.border' = Alpha $h '00'
        'statusBar.border' = Alpha $h '00'
        'titleBar.border' = Alpha $h '00'
    }
}

function Merge-Settings {
    param([hashtable]$Patch)
    $dir = Split-Path $SettingsPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (Test-Path $SettingsPath) {
        Copy-Item $SettingsPath "$SettingsPath.bak-glass-theme" -Force
        $raw = Get-Content $SettingsPath -Raw -Encoding UTF8
        $obj = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { New-Object PSObject }
    } else {
        $obj = New-Object PSObject
    }
    foreach ($key in $Patch.Keys) {
        $val = $Patch[$key]
        $prop = $obj.PSObject.Properties[$key]
        if ($prop) { $prop.Value = $val } else { $obj | Add-Member -NotePropertyName $key -NotePropertyValue $val -Force }
    }
    $json = $obj | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($SettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-VSCodeCli {
    $cmd = Join-Path (Split-Path $CodeExe -Parent) "bin\code.cmd"
    if (Test-Path $cmd) { return $cmd }
    return $CodeExe
}

function Install-ExtensionVsix {
    param([string]$Url, [string]$OutName)
    if (-not (Test-Path $CodeExe)) { throw "VS Code not found at $CodeExe" }
    New-Item -ItemType Directory -Force -Path $ExtDir | Out-Null
    $out = Join-Path $ExtDir $OutName
    if (-not (Test-Path $out)) {
        Write-Host "    Downloading $OutName ..."
        Invoke-WebRequest -Uri $Url -OutFile $out -UseBasicParsing
    }
    $cli = Get-VSCodeCli
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $outText = & $cli --install-extension $out --force 2>&1 | Out-String
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($outText -match 'successfully installed') { Write-Ok "Installed $OutName" }
    elseif ($exit -ne 0) { Write-Warn "Extension install may have failed for $OutName. Try: code --install-extension `"$out`"" }
    else { Write-Ok "Extension present: $OutName" }
}

function Get-RelativePathCompat {
    param([string]$FromDir, [string]$ToPath)
    $from = $FromDir.TrimEnd('\') + '\'
    $fromUri = New-Object System.Uri $from
    $toUri = New-Object System.Uri ((Resolve-Path $ToPath).Path)
    return [Uri]::UnescapeDataString($fromUri.MakeRelativeUri($toUri).ToString()).Replace('\', '/')
}

function Get-WorkbenchProductKey {
    param([string]$WorkbenchHtmlPath, [string]$ProductJsonPath)
    $appDir = Split-Path $ProductJsonPath -Parent
    $rel = Get-RelativePathCompat -FromDir $appDir -ToPath $WorkbenchHtmlPath
    if ($rel -match '^out/(.+)$') { return $matches[1] }
    return $rel
}

function Update-ProductJsonChecksum {
    param([string]$ProductJsonPath, [string]$WorkbenchHtmlPath)
    $hash = [Convert]::ToBase64String(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes($WorkbenchHtmlPath))
    ).TrimEnd('=')
    $key = Get-WorkbenchProductKey -WorkbenchHtmlPath $WorkbenchHtmlPath -ProductJsonPath $ProductJsonPath
    $product = Get-Content $ProductJsonPath -Raw -Encoding UTF8
    $escapedKey = [regex]::Escape($key)
    if ($product -match "`"$escapedKey`":\s*`"[^`"]+`"") {
        $product = $product -replace "`"$escapedKey`":\s*`"[^`"]+`"", "`"$key`": `"$hash`""
    } else {
        $product = $product -replace '("checksums"\s*:\s*\{)', "`$1`n`t`t`"$key`": `"$hash`","
    }
    [System.IO.File]::WriteAllText($ProductJsonPath, $product, [System.Text.UTF8Encoding]::new($false))
    return $key
}

function Update-AllWorkbenchChecksums {
    param([string]$ProductJsonPath, [string[]]$WorkbenchHtmlPaths)
    $keys = @()
    foreach ($path in ($WorkbenchHtmlPaths | Select-Object -Unique)) {
        if ($path -and (Test-Path $path)) {
            $keys += Update-ProductJsonChecksum -ProductJsonPath $ProductJsonPath -WorkbenchHtmlPath $path
        }
    }
    return $keys
}

function Sync-CustomCssWorkbenchMirrors {
    param([string]$PatchedHtml, [string[]]$MirrorPaths, [string]$SkipPath = $null)
    $written = @()
    foreach ($mirrorPath in ($MirrorPaths | Select-Object -Unique)) {
        if (-not $mirrorPath) { continue }
        if ($SkipPath -and $mirrorPath -eq $SkipPath) { continue }
        $mirrorDir = Split-Path $mirrorPath -Parent
        if (-not (Test-Path $mirrorDir)) {
            New-Item -ItemType Directory -Force -Path $mirrorDir | Out-Null
        }
        [System.IO.File]::WriteAllText($mirrorPath, $PatchedHtml, [System.Text.UTF8Encoding]::new($false))
        $written += $mirrorPath
    }
    return $written
}

function Test-WorkbenchPatched {
    param([string]$Path)
    return (Test-Path $Path) -and ((Get-Content $Path -Raw -Encoding UTF8) -match 'VSCODE-CUSTOM-CSS-START')
}

function Patch-Workbench {
    param([string]$CombinedCss, [string]$JsContent)
    $templatePaths = @(
        $vscodePaths.SandboxWorkbenchHtml,
        $vscodePaths.SandboxEsmWorkbenchHtml,
        (Join-Path $vscodePaths.VsCodeDir "electron-browser\workbench\workbench.html")
    )
    if (-not ($templatePaths | Where-Object { $_ -and (Test-Path $_) })) {
        throw "workbench.html not found under $($vscodePaths.VsCodeDir)"
    }

    $indicatorPath = Join-Path $ExtRoot "be5invis.vscode-custom-css-7.4.0\src\statusbar.js"
    if (-not (Test-Path $indicatorPath)) {
        $found = Get-ChildItem $ExtRoot -Filter "be5invis.vscode-custom-css-*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $indicatorPath = Join-Path $found.FullName "src\statusbar.js" }
    }
    if (-not (Test-Path $indicatorPath)) {
        throw "statusbar.js not found. Install 'Custom CSS and JS' extension first (re-run without -SkipExtensions)."
    }

    $indicator = Get-Content $indicatorPath -Raw -Encoding UTF8
    $html = Get-PristineWorkbenchHtml -Paths $templatePaths
    $html = Strip-WorkbenchCsp $html

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

    $patchedPaths = @()
    foreach ($target in ($CustomCssWorkbenchPaths | Select-Object -Unique)) {
        if (-not $target) { continue }
        $targetDir = Split-Path $target -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }
        [System.IO.File]::WriteAllText($target, $html, [System.Text.UTF8Encoding]::new($false))
        $patchedPaths += $target
        Write-Ok "Patched $target"
    }

    $productKeys = Update-AllWorkbenchChecksums -ProductJsonPath $ProductJson -WorkbenchHtmlPaths $patchedPaths
    Write-Ok ("Updated product.json checksums ({0})" -f (($productKeys | Select-Object -Unique) -join ', '))
}

$label = if ($Insiders) { "VS Code Insiders" } else { "VS Code" }
Write-Host @"

  Glass Themes — $label Installer
  Workbench glass + WebGL marble (8 presets)

"@ -ForegroundColor White

if (-not (Test-Path $ManifestPath)) { throw "themes.json not found at $ManifestPath" }
$Manifest = Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $Theme) { $Theme = Select-ThemeInteractive -ManifestObj $Manifest }
$entry = Resolve-ThemeEntry -Id $Theme -ManifestObj $Manifest

$PresetSrc = Join-Path $RepoRoot ($entry.preset -replace '/', '\')
$BaseSrc   = Join-Path $RepoRoot "theme\glass-base.css"
$WbSrc     = Join-Path $RepoRoot "theme\ide-workbench.css"
$MarbleSrc = Join-Path $RepoRoot "theme\marble.js"
$baseTheme = if ($entry.PSObject.Properties['vscodeTheme']) { $entry.vscodeTheme } else { $entry.cursorTheme }

Write-Step "Installing theme: $($entry.name) ($($entry.id)) for $label"
Write-Ok $entry.description
Write-Ok "VS Code: $($vscodePaths.CodeExe)"
Write-Ok "Workbench: $WorkbenchHtml"
Write-Ok "Custom CSS targets (electron-sandbox):"
foreach ($target in $CustomCssWorkbenchPaths) {
    $exists = if (Test-Path $target) { "exists" } else { "will create" }
    Write-Ok "  $target ($exists)"
}

Write-Step "Copying files to $ThemeDir"
New-Item -ItemType Directory -Force -Path (Join-Path $ThemeDir "presets") | Out-Null
Copy-Item $PresetSrc (Join-Path $ThemeDir "presets\$($entry.id).css") -Force
Copy-Item $BaseSrc (Join-Path $ThemeDir "glass-base.css") -Force
Copy-Item $WbSrc (Join-Path $ThemeDir "ide-workbench.css") -Force
Copy-Item $MarbleSrc (Join-Path $ThemeDir "marble.js") -Force
Get-ChildItem (Join-Path $RepoRoot "theme\presets\*.css") | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $ThemeDir "presets\$($_.Name)") -Force
}
@{ id = $entry.id; name = $entry.name; mode = $entry.mode; editor = "vscode" } | ConvertTo-Json | Set-Content (Join-Path $ThemeDir "active-theme.json") -Encoding UTF8
Write-Ok "Theme files copied"

$PresetPath = Join-Path $ThemeDir "presets\$($entry.id).css"
$BasePath   = Join-Path $ThemeDir "glass-base.css"
$WbPath     = Join-Path $ThemeDir "ide-workbench.css"
$JsPath     = Join-Path $ThemeDir "marble.js"
$BundlePath = Join-Path $ThemeDir "active-glass.css"
$presetRaw  = Get-Content $PresetPath -Raw -Encoding UTF8
$combined   = $presetRaw + "`n`n" + (Get-Content $BasePath -Raw -Encoding UTF8) + "`n`n" + (Get-Content $WbPath -Raw -Encoding UTF8)
[System.IO.File]::WriteAllText($BundlePath, $combined, [System.Text.UTF8Encoding]::new($false))

Write-Step "Updating VS Code settings"
$imports = @(
    (To-FileUrl $PresetPath),
    (To-FileUrl $BasePath),
    (To-FileUrl $WbPath),
    (To-FileUrl $JsPath)
)
$settingsPatch = @{
    "vscode_custom_css.imports"     = $imports
    "vscode_custom_css.statusbar"  = $true
    "workbench.colorTheme"         = $baseTheme
    "workbench.colorCustomizations" = (Get-WorkbenchColorCustomizations -PresetCss $presetRaw -Mode $entry.mode)
    "window.titleBarStyle"         = "custom"
}
if ($entry.mode -eq "light") {
    $settingsPatch["workbench.preferredLightColorTheme"] = $baseTheme
    $settingsPatch["workbench.preferredDarkColorTheme"] = $baseTheme
    $settingsPatch["window.autoDetectColorScheme"] = $false
} else {
    $settingsPatch["workbench.preferredDarkColorTheme"] = $baseTheme
    $settingsPatch["workbench.preferredLightColorTheme"] = $baseTheme
}
Merge-Settings $settingsPatch
Write-Ok "settings.json updated (base theme: $baseTheme)"

$cssCheck = Test-CustomCssExtension
if ($cssCheck.Wrong.Count -gt 0) {
    Write-Warn "Wrong Custom CSS extension(s) detected (uninstall these):"
    foreach ($ext in $cssCheck.Wrong) {
        $pkg = Join-Path $ext.FullName "package.json"
        $label = $ext.Name
        if (Test-Path $pkg) {
            $meta = Get-Content $pkg -Raw -Encoding UTF8 | ConvertFrom-Json
            $label = "$($meta.publisher).$($meta.name) ($($meta.displayName))"
        }
        Write-Warn "  $label"
    }
    Write-Warn "Required: be5invis.vscode-custom-css (marketplace display name: Custom CSS and JS Loader)"
}

if (-not $SkipExtensions) {
    Write-Step "Installing required extensions"
    Install-ExtensionVsix `
        -Url "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/be5invis/vsextensions/vscode-custom-css/7.4.0/vspackage" `
        -OutName "vscode-custom-css-7.4.0.vsix"
    Install-ExtensionVsix `
        -Url "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/RimuruChan/vsextensions/vscode-fix-checksums-next/1.4.0/vspackage" `
        -OutName "vscode-fix-checksums-next-1.4.0.vsix"
} elseif (-not $cssCheck.Correct) {
    Write-Warn "Extension be5invis.vscode-custom-css not found. Re-run without -SkipExtensions."
}

if (-not $SkipWorkbenchPatch) {
    Write-Step "Patching VS Code workbench"
    try {
        Patch-Workbench -CombinedCss $combined -JsContent (Get-Content $JsPath -Raw -Encoding UTF8)
    } catch {
        Write-Warn $_.Exception.Message
        Write-Warn "Run VS Code as Administrator, then: Enable Custom CSS and JS -> Fix Checksums: Apply"
    }
}

$cssExt = $cssCheck.Correct
$patchedPrimary = Test-WorkbenchPatched -Path $WorkbenchHtml
$patchedSandbox = ($CustomCssWorkbenchPaths | ForEach-Object { Test-WorkbenchPatched -Path $_ }) -notcontains $false
$patched = $patchedPrimary -and $patchedSandbox
$esmPath = ($CustomCssWorkbenchPaths | Where-Object { $_ -match 'workbench\.esm\.html$' } | Select-Object -First 1)

if (-not $cssExt) {
    Write-Warn "Extension be5invis.vscode-custom-css not found in $ExtRoot. Re-run without -SkipExtensions."
}
if (-not $patched -and -not $SkipWorkbenchPatch) {
    Write-Warn "Workbench was not fully patched. Close VS Code and run installer again as Administrator."
} elseif ($patched) {
    Write-Ok "Workbench pre-patched (sandbox + esm + browser mirrors, CSP stripped)"
    if ($esmPath -and (Test-Path $esmPath)) {
        Write-Ok "workbench.esm.html ready at $esmPath"
    }
}

Write-Host ""
Write-Host "  Done! Theme: $($entry.name) on $label" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Green
Write-Host "    1. Fully quit and restart VS Code" -ForegroundColor Green
if ($patched) {
    Write-Host "    2. Command Palette - Fix Checksums: Apply" -ForegroundColor Green
    Write-Host "    3. Restart again (full quit, not Reload Window)" -ForegroundColor Green
    Write-Host "       Do NOT run Enable Custom CSS and JS - installer already patched all workbench files." -ForegroundColor DarkGreen
} else {
    Write-Host "    2. Run VS Code as Administrator" -ForegroundColor Green
    Write-Host "    3. Re-run this installer, then Fix Checksums: Apply" -ForegroundColor Green
    Write-Host "    4. Restart again (full quit)" -ForegroundColor Green
    Write-Host "       Do NOT run Enable Custom CSS and JS - it only patches one file and breaks mirrors." -ForegroundColor DarkYellow
}
Write-Host ""
Write-Host "  Verify patch:" -ForegroundColor Green
Write-Host "    Select-String -Path `"$($CustomCssWorkbenchPaths[0])`" -Pattern VSCODE-CUSTOM-CSS-START" -ForegroundColor DarkGreen
if ($esmPath) {
    Write-Host "    Select-String -Path `"$esmPath`" -Pattern VSCODE-CUSTOM-CSS-START" -ForegroundColor DarkGreen
}
Write-Host ""
Write-Host "  Switch theme:" -ForegroundColor Green
Write-Host "    powershell -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Theme $($entry.id)" -ForegroundColor Green
Write-Host ""
Write-Host "  Note: Agents window is Cursor-only. VS Code gets full workbench glass + marble." -ForegroundColor Green
Write-Host ""
