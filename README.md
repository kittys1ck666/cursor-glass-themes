# Cursor Glass Themes

Glassmorphism + **WebGL marble** for **Cursor** and **VS Code**.

| Editor | What you get |
|--------|----------------|
| **Cursor** | Full IDE + **Agents glass window** + agent sidebar |
| **VS Code** | Full workbench glass + marble (no Agents — Cursor-only) |

- Frosted glass: sidebar, editor, tabs, terminal, menubar, chat bubbles
- **8 color presets** (dark & light) with matching animated marble
- Bordered **tables**, **lists**, and **code blocks** in chat (readable on marble)
- Same preset vars everywhere the CSS loads

> Unofficial mod. Re-run the installer after editor updates.

## Themes

| ID | Name | Mode | Base editor theme | Description |
|----|------|------|-------------------|-------------|
| `abyss` | Abyss Blue | dark | Abyss | Deep navy + cool blue marble (default) |
| `sakura` | Sakura Pink | **light** | Quiet Light | Pink-white glass, cherry blossom marble |
| `noir` | Noir Mono | dark | Default Dark Modern | Black & white high-contrast |
| `porcelain` | Porcelain | **light** | Default Light Modern | Minimal white & black |
| `aurora` | Aurora | dark | Abyss | Teal, violet, emerald borealis |
| `ember` | Ember Sunset | dark | Abyss | Coral, amber, rose-gold |
| `midnight-gold` | Midnight Gold | dark | Abyss | Dark luxury + champagne veins |
| `neon-tokyo` | Neon Tokyo | dark | Abyss | Synthwave magenta & cyan |

Light presets (`sakura`, `porcelain`) use **dark text** for readability on pale glass.

---

## Install — Cursor

### Windows

```powershell
git clone https://github.com/kittys1ck666/cursor-glass-themes.git
cd cursor-glass-themes

# interactive picker
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1

# or pick a theme directly
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Theme sakura
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Theme noir -SkipExtensions
```

### macOS / Linux

```bash
chmod +x scripts/install.sh scripts/uninstall.sh
./scripts/install.sh           # interactive
./scripts/install.sh sakura    # direct
```

**After install**

1. Fully quit Cursor  
2. Command Palette → **Enable Custom CSS and JS**  
3. Command Palette → **Fix Checksums: Apply**  
4. Restart Cursor  

**Installed to:** `~/.cursor/cursor-abyss-glass/`

**Switch theme:** re-run `install.sh sakura` / `install.ps1 -Theme sakura` — no uninstall needed.

**Uninstall**

- Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1`
- macOS / Linux: `./scripts/uninstall.sh`

Uninstall restores `settings.json` from `settings.json.bak-glass-theme` when available.

> Note: each install overwrites `.bak-glass-theme` with the *current* settings. To keep a pristine pre-glass backup, copy it aside before switching themes.

**Cursor troubleshooting**

| Symptom | Fix |
|---------|-----|
| Theme plain / no marble | Fully quit Cursor → Fix Checksums: Apply → restart. Re-run installer after Cursor updates. |
| `cursor` CLI missing (Linux) | Install CLI or open Cursor and install the two required extensions manually, then re-run installer. |
| Patch fails on `/usr/share/cursor` | Installer uses `sudo` for the patch step only. Close Cursor first. |
| Agents OK, IDE agent sidebar plain | Re-run installer (current CSS keeps markdown tables / AI glass surfaces in IDE). |
| Debug marble attach | In `theme/marble.js` set `DEBUG = true` and/or `SHOW_HUD = true`, reinstall. |

**Verify Cursor patch** (macOS/Linux):

```bash
grep -l 'VSCODE-CUSTOM-CSS-START' \
  /Applications/Cursor.app/Contents/Resources/app/out/vs/code/electron-sandbox/workbench/workbench*.html \
  2>/dev/null || true
```

---

## Install — VS Code

Same glass workbench + marble. No Agents window (Cursor-only feature).

### Windows

```powershell
git clone https://github.com/kittys1ck666/cursor-glass-themes.git
cd cursor-glass-themes

powershell -ExecutionPolicy Bypass -File .\scripts\install-vscode.ps1 -Theme abyss
powershell -ExecutionPolicy Bypass -File .\scripts\install-vscode.ps1 -Theme sakura

# VS Code Insiders
powershell -ExecutionPolicy Bypass -File .\scripts\install-vscode.ps1 -Theme abyss -Insiders
```

### macOS

```bash
git clone https://github.com/kittys1ck666/cursor-glass-themes.git
cd cursor-glass-themes

chmod +x scripts/install-vscode.sh scripts/uninstall-vscode.sh
./scripts/install-vscode.sh abyss
./scripts/install-vscode.sh sakura

# VS Code Insiders
./scripts/install-vscode.sh abyss --insiders
```

The script patches `Visual Studio Code.app` in `/Applications`. If the patch step needs elevated rights, it re-runs itself with `sudo` (enter your Mac password when prompted). **Fully quit VS Code** before installing.

On **Linux**, the installer auto-detects common install paths (`/usr/share/code`, `~/.local/share/code`, `/opt/visual-studio-code`, …) and the `code` / `code-insiders` CLI.

**After install**

1. Fully quit VS Code  
2. **Fix Checksums: Apply** (Command Palette)  
3. Restart VS Code  

If the installer reports **Workbench pre-patched**, you can **skip Enable Custom CSS and JS** — the script already injected CSS into `electron-sandbox/workbench/workbench.html` and `workbench.esm.html`.

If patching failed, close VS Code, run the installer **as Administrator**, then use **Enable Custom CSS and JS** once.

**Installed to:** `~/.vscode/glass-themes/`

**Uninstall**

- Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-vscode.ps1`
- Windows Insiders: `powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-vscode.ps1 -Insiders`
- macOS / Linux: `./scripts/uninstall-vscode.sh`
- macOS / Linux Insiders: `./scripts/uninstall-vscode.sh --insiders`

Uninstall restores `settings.json` from backup when present, and restores workbench HTML (including CSP) from `workbench.*.bak-custom-css` when available.

---

## Requirements

| | Cursor | VS Code |
|---|--------|---------|
| Extensions | [Custom CSS and JS](https://marketplace.visualstudio.com/items?itemName=be5invis.vscode-custom-css) + [Fix Checksums Next](https://marketplace.visualstudio.com/items?itemName=RimuruChan.vscode-fix-checksums-next) | same |
| First patch | Run as Administrator if workbench patch fails | same |
| Backup | `settings.json.bak-glass-theme` created automatically | same |

Installers download extension VSIX files automatically — **do not use `-SkipExtensions`** unless extensions are already installed.

**VS Code troubleshooting**

| Symptom | Fix |
|---------|-----|
| `Unable to locate the installation path of VSCode` | Run `.\scripts\install-vscode.ps1` from the repo folder (not `install.ps1`). Ensure **be5invis.vscode-custom-css** is installed — its marketplace title is **Custom CSS and JS Loader** (publisher: be5invis). Uninstall any *other* Custom CSS extension. |
| `Run VS Code with admin privileges` | Close VS Code completely. Re-run installer as Administrator, or launch VS Code as Administrator and run **Enable Custom CSS and JS** once. |
| `ENOENT workbench.esm.html` | Fixed in current installer: it creates `electron-sandbox/workbench/workbench.esm.html` from the patched workbench. Re-run `install-vscode.ps1`. |
| Theme still plain after install | **Fix Checksums: Apply** → full restart. Re-run installer if VS Code updated. |

**Verify the patch** (PowerShell):

```powershell
$wb = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\*\resources\app\out\vs\code\electron-sandbox\workbench\workbench.html"
Select-String -Path (Resolve-Path $wb) -Pattern "VSCODE-CUSTOM-CSS-START"
```

If the line matches, **Enable Custom CSS and JS** is optional.
**Кратко (RU):**

- Расширение: только **be5invis.vscode-custom-css** (в Marketplace — *Custom CSS and JS Loader*). Другие «Custom CSS» от других авторов — удалить.
- Полностью закройте VS Code → из папки репозитория:
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\install-vscode.ps1 -Theme abyss`
  - macOS: `chmod +x scripts/install-vscode.sh && ./scripts/install-vscode.sh abyss` (sudo, если патч не записывается)
- Command Palette → **Enable Custom CSS and JS** → **Fix Checksums: Apply** → перезапуск.
- После обновления VS Code — снова `install-vscode.ps1`.


Newer VS Code builds use a versioned install folder (`1b50d58d73\resources\app\...`). The installer auto-detects `electron-browser` and mirrors patches into `electron-sandbox`.

---

## Project layout

```
cursor-glass-themes/
├── themes.json                 # manifest (8 presets)
├── theme/
│   ├── presets/*.css           # colors + marble vars per theme
│   ├── glass-base.css          # shared glass, chat, tables, code blocks
│   ├── ide-agent.css           # Cursor agent sidebar only
│   ├── ide-workbench.css       # full classic IDE workbench glass
│   └── marble.js               # WebGL background
└── scripts/
    ├── install.ps1             # Cursor (Windows)
    ├── install.sh              # Cursor (macOS / Linux)
    ├── uninstall.ps1           # Cursor (Windows)
    ├── uninstall.sh            # Cursor (macOS / Linux)
    ├── install-vscode.ps1      # VS Code (Windows)
    ├── install-vscode.sh       # VS Code (macOS / Linux)
    ├── uninstall-vscode.ps1    # VS Code (Windows)
    └── uninstall-vscode.sh     # VS Code (macOS / Linux)
```
**CSS load order:** `preset` → `glass-base` → `ide-agent` (Cursor only) → `ide-workbench` → `marble.js`

---

## Custom theme

1. Copy `theme/presets/abyss.css` → `theme/presets/my-theme.css`
2. Edit CSS variables (`--a-bg`, `--a-glass`, `--a-marble-c1`…`c5`, etc.)
3. Add entry to `themes.json` (`id`, `name`, `mode`, `cursorTheme`)
4. Run `install.ps1 -Theme my-theme` or `install-vscode.ps1 -Theme my-theme`

| Variable | Purpose |
|----------|---------|
| `--a-wb-surface` | Base surface hex for workbench colorCustomizations |
| `--a-fg-bright` | Main text (`#111` on light themes) |
| `--a-glass-input` | Input / code block opacity |
| `--a-blur` / `--a-blur-chat` / `--a-blur-input` | Panel / chat / input blur radii |
| `--a-selection-bg` | Text selection color |
| `--a-btn-primary` / `--a-btn-primary-hover` | Submit button colors |
| `--a-marble-c1`…`c5` | Marble gradient (RGB 0–1, comma-separated) |
| `--a-theme-mode` | `dark` or `light` |

Manual settings snippet (optional): see `settings/cursor-settings.snippet.json`.

---

## Inspiration & credits

IDE glass styling is inspired by **[cursor-ai-liquid-glass-themes](https://github.com/ramonclaudio/cursor-ai-liquid-glass-themes)** by [**ramonclaudio**](https://github.com/ramonclaudio) — an excellent liquid glass mod for Cursor. We extended that approach with a **WebGL marble engine**, **8 presets**, **Agents window** support, and **VS Code** portability.

Built on [vscode-custom-css](https://github.com/be5invis/vscode-custom-css) and [Fix VSCode Checksums Next](https://marketplace.visualstudio.com/items?itemName=RimuruChan.vscode-fix-checksums-next).

## Compared to other projects

| Project | Full IDE | Agents window | Presets | Marble |
|---------|----------|---------------|---------|--------|
| [cursor-ai-liquid-glass-themes](https://github.com/ramonclaudio/cursor-ai-liquid-glass-themes) | Yes (vibrancy) | No | 1 | OS acrylic |
| Forum CSS tweaks | Partial | Partial | 1 | No |
| **This repo — Cursor** | **Yes** | **Yes** | **8** | **WebGL** |
| **This repo — VS Code** | **Yes** | — | **8** | **WebGL** |

## License

MIT — see [LICENSE](LICENSE).
