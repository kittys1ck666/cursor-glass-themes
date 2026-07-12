#!/usr/bin/env bash
# Install Cursor Glass theme (macOS / Linux)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/themes.json"
THEME_DIR="$HOME/.cursor/cursor-abyss-glass"
THEME_ID="${1:-}"

pick_theme() {
  echo ""
  echo "  Available themes:"
  echo ""
  python3 - "$MANIFEST" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
for i, t in enumerate(data["themes"], 1):
    mode = t.get("mode", "dark")
    print(f"  [{i:2}] {t['id']:<16} [{mode}]")
    print(f"       {t['name']} — {t['description']}")
print()
PY
  read -r -p "Enter number or theme id (default: abyss): " choice
  choice="${choice:-abyss}"
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    THEME_ID="$(python3 - "$MANIFEST" "$choice" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
print(data["themes"][int(sys.argv[2]) - 1]["id"])
PY
)"
  else
    THEME_ID="$choice"
  fi
}

if [[ -z "$THEME_ID" ]]; then pick_theme; fi

read_theme() {
  python3 - "$MANIFEST" "$THEME_ID" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
try:
    t = next(x for x in data["themes"] if x["id"] == sys.argv[2])
except StopIteration:
    ids = ", ".join(x["id"] for x in data["themes"])
    raise SystemExit(f"Unknown theme '{sys.argv[2]}'. Available: {ids}")
print(t["preset"]); print(t["cursorTheme"]); print(t["mode"]); print(t["name"])
PY
}

mapfile -t META < <(read_theme)
if [[ ${#META[@]} -lt 4 ]]; then
  echo "Failed to resolve theme '$THEME_ID'" >&2
  exit 1
fi
PRESET_REL="${META[0]}"
CURSOR_THEME="${META[1]}"
THEME_MODE="${META[2]}"
THEME_NAME="${META[3]}"
PRESET_SRC="$REPO_ROOT/${PRESET_REL//\\//}"

case "$(uname -s)" in
  Darwin)
    SETTINGS_PATH="$HOME/Library/Application Support/Cursor/User/settings.json"
    CURSOR_APP="/Applications/Cursor.app/Contents/MacOS/Cursor"
    APP_DIR="/Applications/Cursor.app/Contents/Resources/app"
    ;;
  Linux)
    SETTINGS_PATH="$HOME/.config/Cursor/User/settings.json"
    CURSOR_APP="$(command -v cursor || true)"
    APP_DIR=""
    for base in "$HOME/.local/share/cursor" "/usr/share/cursor" "/opt/Cursor" "/opt/cursor"; do
      if [[ -f "$base/resources/app/product.json" ]]; then
        APP_DIR="$base/resources/app"
        break
      elif [[ -f "$base/product.json" ]]; then
        APP_DIR="$base"
        break
      fi
    done
    ;;
  *) echo "Unsupported OS"; exit 1 ;;
esac

WORKBENCH_HTML=""
PRODUCT_JSON=""
MIRROR_PATHS_JSON="[]"
if [[ -n "${APP_DIR:-}" && -d "$APP_DIR" ]]; then
  PRODUCT_JSON="$APP_DIR/product.json"
  VSCODE_DIR="$APP_DIR/out/vs/code"
  SANDBOX="$VSCODE_DIR/electron-sandbox/workbench/workbench.html"
  SANDBOX_ESM="$VSCODE_DIR/electron-sandbox/workbench/workbench.esm.html"
  BROWSER="$VSCODE_DIR/electron-browser/workbench/workbench.html"
  for candidate in "$SANDBOX" "$SANDBOX_ESM" "$BROWSER"; do
    if [[ -f "$candidate" ]]; then
      WORKBENCH_HTML="$candidate"
      break
    fi
  done
  MIRROR_PATHS_JSON="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "$SANDBOX" "$SANDBOX_ESM" "$BROWSER")"
fi

to_file_url() {
  python3 - "$1" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).resolve().as_uri())
PY
}

maybe_sudo_for_patch() {
  if [[ -z "${PRODUCT_JSON:-}" || ! -f "$PRODUCT_JSON" ]]; then
    return 1
  fi
  if [[ -w "$PRODUCT_JSON" ]]; then
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi
  return 2
}

echo ""
echo "==> Installing theme: $THEME_NAME ($THEME_ID)"
mkdir -p "$THEME_DIR/presets"
cp "$PRESET_SRC" "$THEME_DIR/presets/$THEME_ID.css"
cp "$REPO_ROOT/theme/glass-base.css" "$THEME_DIR/glass-base.css"
cp "$REPO_ROOT/theme/ide-agent.css" "$THEME_DIR/ide-agent.css"
cp "$REPO_ROOT/theme/ide-workbench.css" "$THEME_DIR/ide-workbench.css"
cp "$REPO_ROOT/theme/marble.js" "$THEME_DIR/marble.js"
cp "$REPO_ROOT/theme/patch-indicator.js" "$THEME_DIR/patch-indicator.js"
cp "$REPO_ROOT"/theme/presets/*.css "$THEME_DIR/presets/"
printf '%s\n' "{\"id\":\"$THEME_ID\",\"name\":\"$THEME_NAME\",\"mode\":\"$THEME_MODE\"}" > "$THEME_DIR/active-theme.json"

PRESET_PATH="$THEME_DIR/presets/$THEME_ID.css"
BASE_PATH="$THEME_DIR/glass-base.css"
IDE_PATH="$THEME_DIR/ide-agent.css"
WB_PATH="$THEME_DIR/ide-workbench.css"
JS_PATH="$THEME_DIR/marble.js"
BUNDLE_PATH="$THEME_DIR/active-glass.css"
cat "$PRESET_PATH" "$BASE_PATH" "$IDE_PATH" "$WB_PATH" > "$BUNDLE_PATH"

echo "==> Updating settings.json"
mkdir -p "$(dirname "$SETTINGS_PATH")"
if [[ -f "$SETTINGS_PATH" ]]; then
  cp "$SETTINGS_PATH" "$SETTINGS_PATH.bak-glass-theme"
fi
python3 - "$SETTINGS_PATH" "$(to_file_url "$PRESET_PATH")" "$(to_file_url "$BASE_PATH")" "$(to_file_url "$IDE_PATH")" "$(to_file_url "$WB_PATH")" "$(to_file_url "$JS_PATH")" "$CURSOR_THEME" "$THEME_MODE" "$PRESET_PATH" <<'PY'
import json, pathlib, re, sys
path, preset_url, base, ide, wb, js, cursor_theme, mode, preset_path = sys.argv[1:10]
preset_css = pathlib.Path(preset_path).read_text(encoding="utf-8")
base_hex = "#f6f6f4" if mode == "light" else "#191c22"
m = re.search(r"--a-wb-surface:\s*(#[0-9a-fA-F]{6})", preset_css)
if m:
    base_hex = m.group(1)
else:
    m = re.search(r"--a-bg:\s*(#[0-9a-fA-F]{6})", preset_css)
    if m:
        base_hex = m.group(1)
h = base_hex.lstrip("#")
def a(suffix):
    return f"#{h}{suffix}"
widget = a("ee") if mode == "light" else a("dd")
widget_solid = a("f5") if mode == "light" else a("ee")
colors = {
    "editor.background": a("00"),
    "sideBar.background": a("00"),
    "activityBar.background": a("00"),
    "panel.background": a("00"),
    "editorGroupHeader.tabsBackground": a("00"),
    "editorGroupHeader.noTabsBackground": a("00"),
    "statusBar.background": a("00"),
    "titleBar.activeBackground": a("00"),
    "titleBar.inactiveBackground": a("00"),
    "tab.activeBackground": a("30"),
    "tab.inactiveBackground": a("15"),
    "tab.hoverBackground": a("30"),
    "tab.unfocusedHoverBackground": a("20"),
    "sideBarSectionHeader.background": a("20"),
    "list.activeSelectionBackground": a("40"),
    "list.inactiveSelectionBackground": a("25"),
    "list.hoverBackground": a("25"),
    "list.focusBackground": a("40"),
    "editorWidget.background": widget,
    "editorSuggestWidget.background": widget_solid,
    "editorHoverWidget.background": widget,
    "peekViewEditor.background": a("cc"),
    "peekViewResult.background": a("cc"),
    "peekViewTitle.background": widget,
    "input.background": a("55"),
    "dropdown.background": widget,
    "menu.background": widget_solid,
    "notifications.background": widget_solid,
    "debugToolBar.background": widget,
    "breadcrumb.background": a("00"),
    "breadcrumbPicker.background": widget,
    "terminal.background": a("00"),
    "terminal.foreground": "#e8eef8" if mode != "light" else "#1f1018",
    "terminal.ansiBlack": "#0b1220" if mode != "light" else "#2a2a2a",
    "terminal.ansiRed": "#ff6b7a",
    "terminal.ansiGreen": "#4ae878" if mode != "light" else "#1a7f4b",
    "terminal.ansiYellow": "#f0c674",
    "terminal.ansiBlue": "#7ec8ff" if mode != "light" else "#2f6fed",
    "terminal.ansiMagenta": "#c792ea",
    "terminal.ansiCyan": "#7fdbca",
    "terminal.ansiWhite": "#e8eef8" if mode != "light" else "#1f1018",
    "terminal.ansiBrightBlack": "#6b7a90",
    "terminal.ansiBrightRed": "#ff8a96",
    "terminal.ansiBrightGreen": "#7dffb0",
    "terminal.ansiBrightYellow": "#ffe08a",
    "terminal.ansiBrightBlue": "#a8dcff",
    "terminal.ansiBrightMagenta": "#e0b0ff",
    "terminal.ansiBrightCyan": "#a8fff0",
    "terminal.ansiBrightWhite": "#ffffff",
    "editorGroup.border": a("00"),
    "editorGroupHeader.tabsBorder": a("00"),
    "tab.border": a("00"),
    "tab.activeBorder": a("00"),
    "tab.unfocusedActiveBorder": a("00"),
    "panel.border": a("00"),
    "sideBar.border": a("00"),
    "activityBar.border": a("00"),
    "statusBar.border": a("00"),
    "titleBar.border": a("00"),
}
data = {}
if pathlib.Path(path).exists() and pathlib.Path(path).read_text(encoding="utf-8").strip():
    data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
data["cursor.general.reduceTransparency"] = False
data["vscode_custom_css.imports"] = [preset_url, base, ide, wb, js]
data["vscode_custom_css.statusbar"] = True
data["workbench.colorTheme"] = cursor_theme
data["workbench.colorCustomizations"] = colors
data["window.titleBarStyle"] = "custom"
if mode == "light":
    data["workbench.preferredLightColorTheme"] = cursor_theme
    data["workbench.preferredDarkColorTheme"] = cursor_theme
    data["window.autoDetectColorScheme"] = False
else:
    data["workbench.preferredDarkColorTheme"] = cursor_theme
    data["workbench.preferredLightColorTheme"] = cursor_theme
pathlib.Path(path).write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
PY

echo "==> Installing extensions"
CACHE="$REPO_ROOT/.cache/extensions"
mkdir -p "$CACHE"
CMD=""
if [[ -n "${CURSOR_APP:-}" && -x "$CURSOR_APP" ]]; then
  CMD="$CURSOR_APP"
elif command -v cursor >/dev/null 2>&1; then
  CMD="$(command -v cursor)"
fi

if [[ -n "$CMD" ]]; then
  for pair in \
    "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/be5invis/vsextensions/vscode-custom-css/7.4.0/vspackage|vscode-custom-css-7.4.0.vsix" \
    "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/RimuruChan/vsextensions/vscode-fix-checksums-next/1.4.0/vspackage|vscode-fix-checksums-next-1.4.0.vsix"
  do
    URL="${pair%%|*}"; FILE="${pair##*|}"
    OUT="$CACHE/$FILE"
    [[ -f "$OUT" ]] || curl -fsSL "$URL" -o "$OUT"
    "$CMD" --install-extension "$OUT" || true
  done
else
  echo "    Warning: Cursor CLI not found. Install extensions manually from $CACHE after downloading VSIX files,"
  echo "    or ensure 'cursor' is on PATH, then re-run this installer."
fi

if [[ -n "${PRODUCT_JSON:-}" && -f "$PRODUCT_JSON" ]]; then
  echo "==> Patching workbench (CSP strip + mirrors)"
  PATCH_RC=0
  maybe_sudo_for_patch || PATCH_RC=$?
  RUNNER=(python3)
  if [[ "$PATCH_RC" -eq 2 ]]; then
    echo "    Patching requires administrator privileges — using sudo for patch only..."
    RUNNER=(sudo -E python3)
  elif [[ "$PATCH_RC" -eq 1 ]]; then
    echo "    product.json missing — skip patch"
    RUNNER=()
  fi
  if [[ ${#RUNNER[@]} -gt 0 ]]; then
  INDICATOR_PATH="$REPO_ROOT/theme/patch-indicator.js"
  if ! "${RUNNER[@]}" - "$PRODUCT_JSON" "$BUNDLE_PATH" "$JS_PATH" "$HOME" "$MIRROR_PATHS_JSON" "$INDICATOR_PATH" <<'PY'
import base64, glob, hashlib, json, pathlib, re, sys, uuid

product_path = pathlib.Path(sys.argv[1])
css_path = pathlib.Path(sys.argv[2])
js_path = pathlib.Path(sys.argv[3])
home = pathlib.Path(sys.argv[4])
mirror_paths = [pathlib.Path(p) for p in json.loads(sys.argv[5]) if p]
indicator_path = pathlib.Path(sys.argv[6]) if len(sys.argv) > 6 else None

if indicator_path and indicator_path.is_file():
    indicator = indicator_path.read_text(encoding="utf-8")
else:
    exts = sorted(glob.glob(str(home / ".cursor/extensions/be5invis.vscode-custom-css-*/src/statusbar.js")))
    indicator = pathlib.Path(exts[0]).read_text(encoding="utf-8") if exts else "/* glass indicator */"

css = css_path.read_text(encoding="utf-8")
js = js_path.read_text(encoding="utf-8")
patch_re = re.compile(r"<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*")
block_re = re.compile(r"<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*")
csp_re = re.compile(r'(?s)<meta\s+http-equiv="Content-Security-Policy"[\s\S]*?/>')

def clear_patches(html: str) -> str:
    return block_re.sub("", patch_re.sub("", html))

def get_pristine(paths):
    for p in paths:
        parent = p.parent
        if not parent.is_dir():
            continue
        backups = sorted(parent.glob("workbench.*.bak-custom-css"), key=lambda x: x.stat().st_mtime, reverse=True)
        for bak in backups:
            raw = bak.read_text(encoding="utf-8")
            if "VSCODE-CUSTOM-CSS-START" not in raw:
                print(f"    Using pre-patch backup: {bak.name}")
                return clear_patches(raw)
    for p in paths:
        if p.is_file():
            return clear_patches(p.read_text(encoding="utf-8"))
    raise SystemExit("workbench.html template not found")

html = csp_re.sub("", get_pristine(mirror_paths))
sid = str(uuid.uuid4())
inject = (
    f"<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID {sid} !! -->\n"
    "<!-- !! VSCODE-CUSTOM-CSS-START !! -->\n"
    f"<script>{indicator}</script>\n"
    f"<style>{css}</style>\n"
    f"<script>{js}</script>\n"
    "<!-- !! VSCODE-CUSTOM-CSS-END !! -->\n"
)
html = html.replace("</html>", inject + "</html>")

patched = []
for target in dict.fromkeys(mirror_paths):
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html, encoding="utf-8")
    patched.append(target)
    print(f"    Patched {target}")

app_dir = product_path.parent
product = product_path.read_text(encoding="utf-8")
keys = []
for wb_path in patched:
    digest = base64.b64encode(hashlib.sha256(wb_path.read_bytes()).digest()).decode().rstrip("=")
    rel = wb_path.relative_to(app_dir).as_posix()
    key = rel[4:] if rel.startswith("out/") else rel
    escaped = re.escape(key)
    if re.search(rf'"{escaped}":\s*"[^"]+"', product):
        product = re.sub(rf'"{escaped}":\s*"[^"]+"', f'"{key}": "{digest}"', product)
    else:
        product = re.sub(r'("checksums"\s*:\s*\{)', rf'\1\n\t\t"{key}": "{digest}",', product, count=1)
    keys.append(key)
product_path.write_text(product, encoding="utf-8")
print(f"    Updated product.json checksums ({', '.join(dict.fromkeys(keys))})")
print("    No extension required for glass theme")
PY
  then
    echo "    Warning: workbench patch failed. Close Cursor and re-run (sudo may be required)."
  fi
  fi
elif [[ -z "${APP_DIR:-}" ]]; then
  echo "==> Workbench not found — skip patch. After installing Cursor, re-run this script."
fi

cat <<EOF

  Done! Theme: $THEME_NAME

  Next steps:
    1. Fully quit Cursor
    2. Start Cursor again

  No "Enable Custom CSS" needed — workbench is patched directly.
  If Cursor warns about integrity: Command Palette → Fix Checksums: Apply → restart.

  Switch theme: ./scripts/install.sh sakura
  Uninstall: ./scripts/uninstall.sh

EOF
