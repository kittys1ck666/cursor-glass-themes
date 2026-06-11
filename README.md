# Cursor Glass Themes

Glassmorphism themes for the **Cursor Agents window** (sidebar · chat · editor).

- Frosted glass panels, chat bubbles, menubar
- **WebGL animated marble** background (colors match each theme)
- **8 presets** — dark & light, including readable black text on light themes

> Unofficial mod. Re-run installer after Cursor updates.

## Themes

| ID | Name | Mode | Description |
|----|------|------|-------------|
| `abyss` | Abyss Blue | dark | Deep navy + cool blue marble (default) |
| `sakura` | Sakura Pink | **light** | Pink-white glass, cherry blossom marble |
| `noir` | Noir Mono | dark | Black & white high-contrast |
| `porcelain` | Porcelain | **light** | Minimal white & black, black text |
| `aurora` | Aurora | dark | Teal, violet, emerald borealis |
| `ember` | Ember Sunset | dark | Coral, amber, rose-gold |
| `midnight-gold` | Midnight Gold | dark | Dark luxury + champagne veins |
| `neon-tokyo` | Neon Tokyo | dark | Synthwave magenta & cyan |

Light themes (`sakura`, `porcelain`) use **dark text** (`--a-fg-bright: #0d–#1f`) for readability.

## Quick install (Windows)

**Interactive picker:**

```powershell
git clone https://github.com/kittys1ck666/cursor-glass-themes.git
cd cursor-glass-themes
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

**Direct theme:**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Theme sakura
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Theme porcelain
```

Then **fully restart Cursor**.

### macOS / Linux

```bash
chmod +x scripts/install.sh
./scripts/install.sh          # interactive
./scripts/install.sh sakura     # direct
```

## Switch theme later

Re-run install with another `-Theme` / theme id — no need to uninstall first.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Theme neon-tokyo
```

## File layout

```
cursor-glass-themes/
├── themes.json              # theme manifest
├── theme/
│   ├── presets/             # color + marble vars per theme
│   │   ├── abyss.css
│   │   ├── sakura.css
│   │   └── ...
│   ├── glass-base.css       # layout & glass rules (Agents window)
│   ├── ide-agent.css        # classic IDE agent sidebar (.part.auxiliarybar)
│   └── marble.js            # WebGL bg (reads --a-marble-* vars)
└── scripts/
    ├── install.ps1
    ├── install.sh
    └── uninstall.ps1
```

Installed to `~/.cursor/cursor-glass-themes/` with `active-theme.json`.

## Custom theme

1. Copy `theme/presets/abyss.css` → `theme/presets/my-theme.css`
2. Edit CSS variables (see preset file comments)
3. Add entry to `themes.json`
4. Run `install.ps1 -Theme my-theme`

Key variables:

| Variable | Purpose |
|----------|---------|
| `--a-fg-bright` | Main text (use `#111` on light themes) |
| `--a-glass-light` | Panel glass color |
| `--a-marble-c1`…`c5` | Marble gradient (RGB 0–1, comma-separated) |
| `--a-theme-mode` | `dark` or `light` |

## Requirements

- Cursor **Agents / glass window**
- Extensions: `vscode-custom-css` + `vscode-fix-checksums-next`
- Windows: Administrator on first patch if needed

## Notes

- Installer creates `settings.json.bak-glass-theme` before changing Cursor settings.
- Legacy files `abyss-glass.css` / `abyss-marble.js` were removed; use `glass-base.css` + `presets/` + `marble.js`.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
```

## Compared to other projects

| Project | Agents window | Theme variants | WebGL marble |
|---------|---------------|----------------|--------------|
| [cursor-ai-liquid-glass-themes](https://github.com/ramonclaudio/cursor-ai-liquid-glass-themes) | No | 1 (Midnight) | OS acrylic |
| Forum CSS workarounds | Partial | 1 color tweak | No |
| **This repo** | **Full** | **8 presets** | **Yes** |

## License

MIT — see [LICENSE](LICENSE).
