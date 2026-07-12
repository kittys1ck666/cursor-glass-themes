#!/usr/bin/env bash
# Uninstall Cursor Glass theme (macOS / Linux)
set -euo pipefail

THEME_DIR="$HOME/.cursor/cursor-abyss-glass"

case "$(uname -s)" in
  Darwin)
    SETTINGS_PATH="$HOME/Library/Application Support/Cursor/User/settings.json"
    APP_DIR="/Applications/Cursor.app/Contents/Resources/app"
    ;;
  Linux)
    SETTINGS_PATH="$HOME/.config/Cursor/User/settings.json"
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
  *) echo "Unsupported OS. Use uninstall.ps1 on Windows."; exit 1 ;;
esac

PRODUCT_JSON=""
WORKBENCH_PATHS_JSON="[]"
if [[ -n "${APP_DIR:-}" && -d "$APP_DIR" ]]; then
  PRODUCT_JSON="$APP_DIR/product.json"
  VSCODE_DIR="$APP_DIR/out/vs/code"
  WORKBENCH_PATHS_JSON="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' \
    "$VSCODE_DIR/electron-sandbox/workbench/workbench.html" \
    "$VSCODE_DIR/electron-sandbox/workbench/workbench.esm.html" \
    "$VSCODE_DIR/electron-browser/workbench/workbench.html")"
fi

echo "==> Removing workbench patch"
if [[ -n "$PRODUCT_JSON" && -f "$PRODUCT_JSON" ]]; then
  if [[ ! -w "$PRODUCT_JSON" && "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Re-running with sudo..."
    exec sudo -E "$0"
  fi
  python3 - "$PRODUCT_JSON" "$WORKBENCH_PATHS_JSON" <<'PY'
import base64, hashlib, json, pathlib, re, sys

product_path = pathlib.Path(sys.argv[1])
paths = [pathlib.Path(p) for p in json.loads(sys.argv[2])]
patch_re = re.compile(r"<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*")
block_re = re.compile(r"<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*")

def restore_from_backup(target: pathlib.Path) -> bool:
    parent = target.parent
    if not parent.is_dir():
        return False
    specific = sorted(parent.glob(f"{target.name}.*.bak-custom-css"), key=lambda x: x.stat().st_mtime, reverse=True)
    general = sorted(parent.glob("workbench.*.bak-custom-css"), key=lambda x: x.stat().st_mtime, reverse=True)
    for bak in specific + general:
        raw = bak.read_text(encoding="utf-8")
        if "VSCODE-CUSTOM-CSS-START" in raw:
            continue
        target.write_text(raw, encoding="utf-8")
        print(f"    restored CSP+html from {bak.name} -> {target}")
        return True
    return False

restored = []
for path in paths:
    if path.is_file() and "VSCODE-CUSTOM-CSS-START" not in path.read_text(encoding="utf-8"):
        if restore_from_backup(path):
            restored.append(path)
        continue
    if restore_from_backup(path):
        restored.append(path)
        continue
    if not path.is_file():
        continue
    html = path.read_text(encoding="utf-8")
    if "VSCODE-CUSTOM-CSS-START" not in html:
        continue
    html = patch_re.sub("", html)
    html = block_re.sub("", html)
    path.write_text(html, encoding="utf-8")
    restored.append(path)
    print(f"    stripped glass patch (CSP backup not found): {path}")

if restored:
    app_dir = product_path.parent
    product = product_path.read_text(encoding="utf-8")
    for wb_path in restored:
        if not wb_path.is_file():
            continue
        digest = base64.b64encode(hashlib.sha256(wb_path.read_bytes()).digest()).decode().rstrip("=")
        rel = wb_path.relative_to(app_dir).as_posix()
        key = rel[4:] if rel.startswith("out/") else rel
        product = re.sub(re.escape(f'"{key}"') + r':\s*"[^"]+"', f'"{key}": "{digest}"', product)
    product_path.write_text(product, encoding="utf-8")
else:
    print("    no glass patch found")
PY
else
  echo "    workbench not found (skip)"
fi

echo "==> Cleaning settings.json"
BACKUP="$SETTINGS_PATH.bak-glass-theme"
if [[ -f "$BACKUP" ]]; then
  cp "$BACKUP" "$SETTINGS_PATH"
  echo "    Restored settings from settings.json.bak-glass-theme"
elif [[ -f "$SETTINGS_PATH" ]]; then
  python3 - "$SETTINGS_PATH" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for key in (
    "vscode_custom_css.imports",
    "vscode_custom_css.statusbar",
    "cursor.general.reduceTransparency",
    "workbench.colorCustomizations",
    "workbench.preferredLightColorTheme",
    "workbench.preferredDarkColorTheme",
    "window.autoDetectColorScheme",
):
    data.pop(key, None)
path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
print("    Glass settings keys removed (no backup found)")
PY
else
  echo "    settings.json not found (skip)"
fi

echo "==> Removing theme files"
if [[ -d "$THEME_DIR" ]]; then
  rm -rf "$THEME_DIR"
  echo "    $THEME_DIR removed"
fi

echo ""
echo "Restart Cursor."
echo "If needed, compare with: $BACKUP"
echo ""
