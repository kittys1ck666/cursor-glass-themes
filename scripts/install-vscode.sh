#!/usr/bin/env bash
# Install Glass Themes for VS Code (macOS / Linux)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/themes.json"
THEME_DIR="$HOME/.vscode/glass-themes"
EXT_DIR="$REPO_ROOT/.cache/extensions"
EXT_ROOT="$HOME/.vscode/extensions"
REQUIRED_CSS_EXT="be5invis.vscode-custom-css"

THEME_ID=""
INSIDERS=0
SKIP_EXTENSIONS=0
SKIP_WORKBENCH_PATCH=0

usage() {
  cat <<'EOF'
Usage: ./scripts/install-vscode.sh [theme-id] [options]

Options:
  --insiders              Target VS Code Insiders
  --skip-extensions       Do not install extension VSIX files
  --skip-workbench-patch  Only copy theme files and update settings
  -h, --help              Show this help

Examples:
  ./scripts/install-vscode.sh
  ./scripts/install-vscode.sh abyss
  ./scripts/install-vscode.sh sakura --insiders
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --insiders) INSIDERS=1; shift ;;
    --skip-extensions) SKIP_EXTENSIONS=1; shift ;;
    --skip-workbench-patch) SKIP_WORKBENCH_PATCH=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)
      if [[ -z "$THEME_ID" ]]; then
        THEME_ID="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

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

[[ -z "$THEME_ID" ]] && pick_theme

read_theme_meta() {
  python3 - "$MANIFEST" "$THEME_ID" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
t = next(x for x in data["themes"] if x["id"] == sys.argv[2])
base = t.get("vscodeTheme", t.get("cursorTheme", "Abyss"))
print(t["preset"])
print(base)
print(t["mode"])
print(t["name"])
print(t["description"])
PY
}

mapfile -t META < <(read_theme_meta)
PRESET_REL="${META[0]}"
BASE_THEME="${META[1]}"
THEME_MODE="${META[2]}"
THEME_NAME="${META[3]}"
THEME_DESC="${META[4]}"
PRESET_SRC="$REPO_ROOT/${PRESET_REL//\\//}"

resolve_vscode_paths() {
  python3 - "$INSIDERS" <<'PY'
import json, os, pathlib, sys

insiders = sys.argv[1] == "1"
home = pathlib.Path.home()

if sys.platform == "darwin":
    app_name = "Visual Studio Code - Insiders.app" if insiders else "Visual Studio Code.app"
    candidates = [
        pathlib.Path("/Applications") / app_name,
        home / "Applications" / app_name,
    ]
    settings = home / "Library/Application Support"
    settings /= "Code - Insiders" if insiders else "Code"
    settings = settings / "User/settings.json"
elif sys.platform.startswith("linux"):
    candidates = [
        pathlib.Path("/usr/share/code"),
        pathlib.Path("/usr/share/code-insiders"),
        home / ".local/share/code",
        home / ".local/share/code-insiders",
        pathlib.Path("/opt/visual-studio-code"),
    ]
    settings = home / ".config"
    settings = settings / ("Code - Insiders" if insiders else "Code") / "User/settings.json"
else:
    raise SystemExit("Unsupported OS. Use install-vscode.ps1 on Windows.")

app_dir = None
app_root = None
for root in candidates:
    if sys.platform == "darwin":
        resources = root / "Contents/Resources/app"
        if (resources / "product.json").is_file():
            app_dir = resources
            app_root = root
            break
    else:
        resources = root / "resources/app" if (root / "resources/app/product.json").is_file() else root
        if (resources / "product.json").is_file():
            app_dir = resources
            app_root = root
            break

if not app_dir:
    label = "VS Code Insiders" if insiders else "VS Code"
    raise SystemExit(f"{label} not found. Install it first.")

vscode_dir = app_dir / "out/vs/code"
browser = vscode_dir / "electron-browser/workbench/workbench.html"
sandbox = vscode_dir / "electron-sandbox/workbench/workbench.html"
sandbox_esm = vscode_dir / "electron-sandbox/workbench/workbench.esm.html"

canonical = None
for candidate in (sandbox, sandbox_esm, browser):
    if candidate.is_file():
        canonical = candidate
        break
if not canonical:
    for found in app_dir.rglob("workbench.html"):
        if found.parent.name == "workbench":
            canonical = found
            break
if not canonical:
    raise SystemExit("workbench.html not found under VS Code app bundle")

mirror_paths = [sandbox, sandbox_esm, browser]
if sys.platform == "darwin":
    code_cli = app_dir / "bin/code"
else:
    code_cli = pathlib.Path("/usr/bin/code")
    if not code_cli.is_file():
        code_cli = pathlib.Path(os.environ.get("PATH", "")).joinpath("code")

print(json.dumps({
    "app_dir": str(app_dir),
    "app_root": str(app_root),
    "product_json": str(app_dir / "product.json"),
    "workbench_html": str(canonical),
    "mirror_paths": [str(p) for p in mirror_paths],
    "settings_path": str(settings),
    "code_cli": str(code_cli),
    "label": "VS Code Insiders" if insiders else "VS Code",
}))
PY
}

PATHS_JSON="$(resolve_vscode_paths)"
APP_DIR="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["app_dir"])' "$PATHS_JSON")"
PRODUCT_JSON="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["product_json"])' "$PATHS_JSON")"
WORKBENCH_HTML="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["workbench_html"])' "$PATHS_JSON")"
SETTINGS_PATH="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["settings_path"])' "$PATHS_JSON")"
CODE_CLI="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["code_cli"])' "$PATHS_JSON")"
VSCODE_LABEL="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["label"])' "$PATHS_JSON")"
MIRROR_PATHS_JSON="$(python3 -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1])["mirror_paths"]))' "$PATHS_JSON")"

to_file_url() {
  python3 - "$1" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).resolve().as_uri())
PY
}

maybe_sudo_for_patch() {
  if [[ "$SKIP_WORKBENCH_PATCH" -eq 1 ]]; then
    return 0
  fi
  if [[ ! -w "$PRODUCT_JSON" ]]; then
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
      echo ""
      echo "Patching $VSCODE_LABEL.app requires administrator privileges."
      echo "Re-running with sudo..."
      exec sudo -E "$0" ${THEME_ID:+$THEME_ID} \
        $( [[ "$INSIDERS" -eq 1 ]] && echo --insiders ) \
        $( [[ "$SKIP_EXTENSIONS" -eq 1 ]] && echo --skip-extensions ) \
        $( [[ "$SKIP_WORKBENCH_PATCH" -eq 1 ]] && echo --skip-workbench-patch )
    fi
  fi
}

echo ""
echo "  Glass Themes — $VSCODE_LABEL Installer"
echo "  Workbench glass + WebGL marble (8 presets)"
echo ""

echo "==> Installing theme: $THEME_NAME ($THEME_ID) for $VSCODE_LABEL"
echo "    $THEME_DESC"
echo "    VS Code app: $APP_DIR"
echo "    Workbench: $WORKBENCH_HTML"

mkdir -p "$THEME_DIR/presets"
cp "$PRESET_SRC" "$THEME_DIR/presets/$THEME_ID.css"
cp "$REPO_ROOT/theme/glass-base.css" "$THEME_DIR/glass-base.css"
cp "$REPO_ROOT/theme/ide-workbench.css" "$THEME_DIR/ide-workbench.css"
cp "$REPO_ROOT/theme/marble.js" "$THEME_DIR/marble.js"
cp "$REPO_ROOT"/theme/presets/*.css "$THEME_DIR/presets/"
printf '%s\n' "{\"id\":\"$THEME_ID\",\"name\":\"$THEME_NAME\",\"mode\":\"$THEME_MODE\",\"editor\":\"vscode\"}" > "$THEME_DIR/active-theme.json"
echo "    Theme files copied to $THEME_DIR"

PRESET_PATH="$THEME_DIR/presets/$THEME_ID.css"
BASE_PATH="$THEME_DIR/glass-base.css"
WB_PATH="$THEME_DIR/ide-workbench.css"
JS_PATH="$THEME_DIR/marble.js"
BUNDLE_PATH="$THEME_DIR/active-glass.css"
cat "$PRESET_PATH" "$BASE_PATH" "$WB_PATH" > "$BUNDLE_PATH"

echo "==> Updating VS Code settings"
mkdir -p "$(dirname "$SETTINGS_PATH")"
if [[ -f "$SETTINGS_PATH" ]]; then
  cp "$SETTINGS_PATH" "$SETTINGS_PATH.bak-glass-theme"
fi
python3 - "$SETTINGS_PATH" "$(to_file_url "$PRESET_PATH")" "$(to_file_url "$BASE_PATH")" "$(to_file_url "$WB_PATH")" "$(to_file_url "$JS_PATH")" "$BASE_THEME" "$THEME_MODE" "$PRESET_PATH" <<'PY'
import json, pathlib, re, sys
path, preset_url, base, wb, js, base_theme, mode, preset_path = sys.argv[1:9]
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
data["vscode_custom_css.imports"] = [preset_url, base, wb, js]
data["vscode_custom_css.statusbar"] = True
data["workbench.colorTheme"] = base_theme
data["workbench.colorCustomizations"] = colors
data["window.titleBarStyle"] = "custom"
if mode == "light":
    data["workbench.preferredLightColorTheme"] = base_theme
    data["workbench.preferredDarkColorTheme"] = base_theme
    data["window.autoDetectColorScheme"] = False
else:
    data["workbench.preferredDarkColorTheme"] = base_theme
    data["workbench.preferredLightColorTheme"] = base_theme
pathlib.Path(path).write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"    settings.json updated (base theme: {base_theme})")
PY

if [[ "$SKIP_EXTENSIONS" -eq 0 ]]; then
  echo "==> Installing required extensions"
  mkdir -p "$EXT_DIR"
  for pair in \
    "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/be5invis/vsextensions/vscode-custom-css/7.4.0/vspackage|vscode-custom-css-7.4.0.vsix" \
    "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/RimuruChan/vsextensions/vscode-fix-checksums-next/1.4.0/vspackage|vscode-fix-checksums-next-1.4.0.vsix"
  do
    URL="${pair%%|*}"
    FILE="${pair##*|}"
    OUT="$EXT_DIR/$FILE"
    if [[ ! -f "$OUT" ]]; then
      echo "    Downloading $FILE ..."
      curl -fsSL "$URL" -o "$OUT"
    fi
    if [[ -x "$CODE_CLI" ]]; then
      "$CODE_CLI" --install-extension "$OUT" --force || true
    elif command -v code >/dev/null 2>&1; then
      code --install-extension "$OUT" --force || true
    else
      echo "    Warning: VS Code CLI not found. Install extensions manually from $OUT"
    fi
  done
fi

if [[ "$SKIP_WORKBENCH_PATCH" -eq 0 ]]; then
  maybe_sudo_for_patch
  echo "==> Patching VS Code workbench"
  if ! python3 - "$PRODUCT_JSON" "$BUNDLE_PATH" "$JS_PATH" "$EXT_ROOT" "$MIRROR_PATHS_JSON" <<'PY'
import base64, glob, hashlib, json, pathlib, re, sys, uuid

product_path = pathlib.Path(sys.argv[1])
css_path = pathlib.Path(sys.argv[2])
js_path = pathlib.Path(sys.argv[3])
ext_root = pathlib.Path(sys.argv[4])
mirror_paths = [pathlib.Path(p) for p in json.loads(sys.argv[5])]

exts = sorted(glob.glob(str(ext_root / "be5invis.vscode-custom-css-*/src/statusbar.js")))
if not exts:
    raise SystemExit("statusbar.js not found. Re-run without --skip-extensions.")

indicator = pathlib.Path(exts[0]).read_text(encoding="utf-8")
css = css_path.read_text(encoding="utf-8")
js = js_path.read_text(encoding="utf-8")

patch_re = re.compile(r"<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*")
block_re = re.compile(r"<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*")
csp_re = re.compile(r'(?s)<meta\s+http-equiv="Content-Security-Policy"[\s\S]*?/>')

def clear_patches(html: str) -> str:
    html = patch_re.sub("", html)
    html = block_re.sub("", html)
    return html

def strip_csp(html: str) -> str:
    return csp_re.sub("", html)

def get_pristine(paths):
    for p in paths:
        if not p:
            continue
        parent = p.parent
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

template_paths = [p for p in mirror_paths if p]
html = strip_csp(get_pristine(template_paths))
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

patched_paths = []
for target in dict.fromkeys(mirror_paths):
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html, encoding="utf-8")
    patched_paths.append(target)
    print(f"    Patched {target}")

app_dir = product_path.parent
product = product_path.read_text(encoding="utf-8")
keys = []
for wb_path in patched_paths:
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
PY
  then
    echo "    Warning: workbench patch failed. Close VS Code and re-run with sudo."
  fi
fi

PATCHED=1
for target in $(python3 -c 'import json,sys; print(" ".join(json.loads(sys.argv[1])))' "$MIRROR_PATHS_JSON"); do
  if [[ ! -f "$target" ]] || ! grep -q 'VSCODE-CUSTOM-CSS-START' "$target"; then
    PATCHED=0
    break
  fi
done

cat <<EOF

  Done! Theme: $THEME_NAME on $VSCODE_LABEL

  Next steps:
    1. Fully quit and restart VS Code
EOF

if [[ "$PATCHED" -eq 1 && "$SKIP_WORKBENCH_PATCH" -eq 0 ]]; then
  cat <<'EOF'
    2. Command Palette → Fix Checksums: Apply
    3. Restart again (full quit, not Reload Window)
       Do NOT run Enable Custom CSS and JS — installer already patched all workbench files.
EOF
else
  cat <<'EOF'
    2. Close VS Code, re-run this script with sudo if patch failed
    3. Command Palette → Fix Checksums: Apply → restart
       Do NOT run Enable Custom CSS and JS — it only patches one file and breaks mirrors.
EOF
fi

cat <<EOF

  Verify patch:
    grep -l 'VSCODE-CUSTOM-CSS-START' "$APP_DIR/out/vs/code/electron-sandbox/workbench/"workbench*.html

  Switch theme:
    ./scripts/install-vscode.sh $THEME_ID

  Note: Agents window is Cursor-only. VS Code gets full workbench glass + marble.

EOF
