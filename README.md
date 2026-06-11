# Cursor Glass Themes

Glassmorphism themes for **Cursor** — full classic IDE + **Agents glass window**.

- Frosted glass panels, chat bubbles, menubar, sidebar, editor, terminal
- **WebGL animated marble** background (colors match each theme)
- **8 presets** — dark & light, including readable black text on light themes
- Bordered tables & listings in chat (readable on marble)

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
│   ├── glass-base.css       # shared glass + chat tables/lists
│   ├── ide-agent.css        # IDE agent sidebar (.part.auxiliarybar)
│   ├── ide-workbench.css    # full classic IDE workbench glass
│   └── marble.js            # WebGL bg (reads --a-marble-* vars)
└── scripts/
    ├── install.ps1
    ├── install.sh
    └── uninstall.ps1
```

Installed to `~/.cursor/cursor-abyss-glass/` with `active-theme.json`.

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

## Inspiration & credits

Classic IDE glass styling (transparent workbench shells, tabs, lists, widgets) is inspired by **[cursor-ai-liquid-glass-themes](https://github.com/ramonclaudio/cursor-ai-liquid-glass-themes)** by [**ramonclaudio**](https://github.com/ramonclaudio) — a great liquid glass mod for Cursor. That project showed how to make the full IDE feel glassy; we built on that idea with our **WebGL marble engine**, **8 color presets**, **Agents window** support, and **IDE agent sidebar** parity.

Also uses [vscode-custom-css](https://github.com/be5invis/vscode-custom-css) and [Fix VSCode Checksums Next](https://marketplace.visualstudio.com/items?itemName=RimuruChan.vscode-fix-checksums-next).

## Compared to other projects

| Project | Full IDE | Agents window | Theme variants | WebGL marble |
|---------|----------|---------------|----------------|--------------|
| [cursor-ai-liquid-glass-themes](https://github.com/ramonclaudio/cursor-ai-liquid-glass-themes) | **Yes** (vibrancy) | No | 1 (Midnight) | OS acrylic |
| Forum CSS workarounds | Partial | Partial | 1 tweak | No |
| **This repo** | **Yes** (CSS + marble) | **Full** | **8 presets** | **Yes** |

## License

MIT — see [LICENSE](LICENSE).

yukigawa & Cursor AI
