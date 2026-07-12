#!/usr/bin/env bash
# Uninstall Cursor Glass theme (macOS / Linux)
set -euo pipefail

THEME_DIR="$HOME/.cursor/cursor-abyss-glass"

case "$(uname -s)" in
  Darwin)
    SETTINGS_PATH="$HOME/Library/Application Support/Cursor/User/settings.json"
    WORKBENCH_HTML="/Applications/Cursor.app/Contents/Resources/app/out/vs/code/electron-sandbox/workbench/workbench.html"
    PRODUCT_JSON="/Applications/Cursor.app/Contents/Resources/app/product.json"
    ;;
  Linux)
    SETTINGS_PATH="$HOME/.config/Cursor/User/settings.json"
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
  *) echo "Unsupported OS. Use uninstall.ps1 on Windows."; exit 1 ;;
esac

echo "==> Removing workbench patch"
if [[ -f "${WORKBENCH_HTML:-}" ]]; then
  python3 - "$WORKBENCH_HTML" "$PRODUCT_JSON" <<'PY'
import base64, hashlib, pathlib, re, sys

html_path = pathlib.Path(sys.argv[1])
product_path = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None

html = html_path.read_text(encoding="utf-8")
if "VSCODE-CUSTOM-CSS-START" not in html:
    print("    no glass patch found")
else:
    html = re.sub(r"<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*", "", html)
    html = re.sub(r"<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*", "", html)
    html_path.write_text(html, encoding="utf-8")
    print(f"    restored {html_path}")
    if product_path and product_path.is_file():
        digest = base64.b64encode(hashlib.sha256(html_path.read_bytes()).digest()).decode().rstrip("=")
        product = product_path.read_text(encoding="utf-8")
        product = re.sub(
            r'"vs/code/electron-sandbox/workbench/workbench.html":\s*"[^"]+"',
            f'"vs/code/electron-sandbox/workbench/workbench.html": "{digest}"',
            product,
        )
        product_path.write_text(product, encoding="utf-8")
PY
else
  echo "    workbench.html not found (skip)"
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
# Keep workbench.colorTheme / titleBarStyle — user may have set them intentionally
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
