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
chmod +x scripts/install.sh
./scripts/install.sh           # interactive
./scripts/install.sh sakura    # direct
```

**After install**

1. Fully quit Cursor  
2. Command Palette → **Enable Custom CSS and JS**  
3. Command Palette → **Fix Checksums: Apply**  
4. Restart Cursor  

**Installed to:** `~/.cursor/cursor-abyss-glass/`

**Switch theme:** re-run `install.ps1 -Theme <id>` — no uninstall needed.

**Uninstall:** `powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1`

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

**After install**

1. Fully quit VS Code  
2. **Enable Custom CSS and JS**  
3. **Fix Checksums: Apply**  
4. Restart VS Code  

**Installed to:** `~/.vscode/glass-themes/`

**Uninstall:** `powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-vscode.ps1`

---

## Requirements

| | Cursor | VS Code |
|---|--------|---------|
| Extensions | [Custom CSS and JS](https://marketplace.visualstudio.com/items?itemName=be5invis.vscode-custom-css) + [Fix Checksums Next](https://marketplace.visualstudio.com/items?itemName=RimuruChan.vscode-fix-checksums-next) | same |
| First patch | Run as Administrator if workbench patch fails | same |
| Backup | `settings.json.bak-glass-theme` created automatically | same |

Installers download extension VSIX files automatically — **do not use `-SkipExtensions`** unless extensions are already installed.

**VS Code troubleshooting:** newer builds use a versioned install folder (`electron-browser/workbench`). The installer auto-detects this. If themes still don't load: install **Custom CSS and JS** → **Enable Custom CSS and JS** → **Fix Checksums: Apply** → full restart.

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
    ├── install-vscode.ps1      # VS Code (Windows)
    ├── uninstall.ps1           # Cursor
    └── uninstall-vscode.ps1    # VS Code
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
| `--a-fg-bright` | Main text (`#111` on light themes) |
| `--a-glass-input` | Input / code block opacity |
| `--a-marble-c1`…`c5` | Marble gradient (RGB 0–1, comma-separated) |
| `--a-theme-mode` | `dark` or `light` |

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
