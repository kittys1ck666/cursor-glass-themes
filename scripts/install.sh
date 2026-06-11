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
t = next(x for x in data["themes"] if x["id"] == sys.argv[2])
print(t["preset"]); print(t["cursorTheme"]); print(t["mode"]); print(t["name"])
PY
}

mapfile -t META < <(read_theme)
PRESET_REL="${META[0]}"
CURSOR_THEME="${META[1]}"
THEME_MODE="${META[2]}"
THEME_NAME="${META[3]}"
PRESET_SRC="$REPO_ROOT/${PRESET_REL//\\//}"

case "$(uname -s)" in
  Darwin)
    SETTINGS_PATH="$HOME/Library/Application Support/Cursor/User/settings.json"
    CURSOR_APP="/Applications/Cursor.app/Contents/MacOS/Cursor"
    WORKBENCH_HTML="/Applications/Cursor.app/Contents/Resources/app/out/vs/code/electron-sandbox/workbench/workbench.html"
    PRODUCT_JSON="/Applications/Cursor.app/Contents/Resources/app/product.json"
    ;;
  Linux)
    SETTINGS_PATH="$HOME/.config/Cursor/User/settings.json"
    CURSOR_APP="$(command -v cursor || true)"
    WORKBENCH_HTML=""
    PRODUCT_JSON=""
    for base in "$HOME/.local/share/cursor" "/usr/share/cursor" "/opt/Cursor"; do
      if [[ -f "$base/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html" ]]; then
        WORKBENCH_HTML="$base/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html"
        PRODUCT_JSON="$base/resources/app/product.json"
        break
      fi
    done
    ;;
  *) echo "Unsupported OS"; exit 1 ;;
esac

to_file_url() {
  python3 - "$1" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).resolve().as_uri())
PY
}

echo ""
echo "==> Installing theme: $THEME_NAME ($THEME_ID)"
mkdir -p "$THEME_DIR/presets"
cp "$PRESET_SRC" "$THEME_DIR/presets/$THEME_ID.css"
cp "$REPO_ROOT/theme/glass-base.css" "$THEME_DIR/glass-base.css"
cp "$REPO_ROOT/theme/ide-agent.css" "$THEME_DIR/ide-agent.css"
cp "$REPO_ROOT/theme/ide-workbench.css" "$THEME_DIR/ide-workbench.css"
cp "$REPO_ROOT/theme/marble.js" "$THEME_DIR/marble.js"
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
CMD="${CURSOR_APP:-cursor}"
if [[ -x "$CMD" || -n "${CURSOR_APP:-}" ]]; then
  for pair in \
    "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/be5invis/vsextensions/vscode-custom-css/7.4.0/vspackage|vscode-custom-css-7.4.0.vsix" \
    "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/RimuruChan/vsextensions/vscode-fix-checksums-next/1.4.0/vspackage|vscode-fix-checksums-next-1.4.0.vsix"
  do
    URL="${pair%%|*}"; FILE="${pair##*|}"
    OUT="$CACHE/$FILE"
    [[ -f "$OUT" ]] || curl -fsSL "$URL" -o "$OUT"
    "$CMD" --install-extension "$OUT" || true
  done
fi

if [[ -f "${WORKBENCH_HTML:-}" ]]; then
  echo "==> Patching workbench"
  python3 - "$WORKBENCH_HTML" "$PRODUCT_JSON" "$BUNDLE_PATH" "$JS_PATH" "$HOME" <<'PY' || true
import hashlib, base64, glob, pathlib, re, sys, uuid
html_path, product_path, css_path, js_path, home = sys.argv[1:6]
exts = glob.glob(str(pathlib.Path(home)/".cursor/extensions/be5invis.vscode-custom-css-*/src/statusbar.js"))
if not exts:
    print("    Run Enable Custom CSS and JS in Cursor")
    sys.exit(0)
indicator = pathlib.Path(exts[0]).read_text(encoding="utf-8")
css = pathlib.Path(css_path).read_text(encoding="utf-8")
js = pathlib.Path(js_path).read_text(encoding="utf-8")
html = pathlib.Path(html_path).read_text(encoding="utf-8")
html = re.sub(r'<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*', '', html)
html = re.sub(r'<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*', '', html)
sid = str(uuid.uuid4())
inject = f"<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID {sid} !! -->\n<!-- !! VSCODE-CUSTOM-CSS-START !! -->\n<script>{indicator}</script>\n<style>{css}</style>\n<script>{js}</script>\n<!-- !! VSCODE-CUSTOM-CSS-END !! -->\n"
html = html.replace("</html>", inject + "</html>")
pathlib.Path(html_path).write_text(html, encoding="utf-8")
digest = base64.b64encode(hashlib.sha256(html.encode("utf-8")).digest()).decode().rstrip("=")
product = pathlib.Path(product_path).read_text(encoding="utf-8")
product = re.sub(r'"vs/code/electron-sandbox/workbench/workbench.html":\s*"[^"]+"', f'"vs/code/electron-sandbox/workbench/workbench.html": "{digest}"', product)
pathlib.Path(product_path).write_text(product, encoding="utf-8")
print("    workbench patched")
PY
fi

cat <<EOF

  Done! Theme: $THEME_NAME

  Restart Cursor. Switch theme: ./scripts/install.sh sakura

EOF
