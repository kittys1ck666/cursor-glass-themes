#!/usr/bin/env bash
# Uninstall Glass Themes from VS Code (macOS / Linux)
set -euo pipefail

INSIDERS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --insiders) INSIDERS=1; shift ;;
    -h|--help)
      echo "Usage: ./scripts/uninstall-vscode.sh [--insiders]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

THEME_DIR="$HOME/.vscode/glass-themes"

resolve_paths() {
  python3 - "$INSIDERS" <<'PY'
import json, pathlib, sys

insiders = sys.argv[1] == "1"
home = pathlib.Path.home()

if sys.platform == "darwin":
    app_name = "Visual Studio Code - Insiders.app" if insiders else "Visual Studio Code.app"
    candidates = [pathlib.Path("/Applications") / app_name, home / "Applications" / app_name]
    settings = home / "Library/Application Support"
    settings = (settings / ("Code - Insiders" if insiders else "Code")) / "User/settings.json"
elif sys.platform.startswith("linux"):
    candidates = [
        pathlib.Path("/usr/share/code"),
        pathlib.Path("/usr/share/code-insiders"),
        home / ".local/share/code",
        home / ".local/share/code-insiders",
        pathlib.Path("/opt/visual-studio-code"),
    ]
    settings = home / ".config" / ("Code - Insiders" if insiders else "Code") / "User/settings.json"
else:
    raise SystemExit("Unsupported OS. Use uninstall-vscode.ps1 on Windows.")

app_dir = None
for root in candidates:
    if sys.platform == "darwin":
        resources = root / "Contents/Resources/app"
        if (resources / "product.json").is_file():
            app_dir = resources
            break
    else:
        resources = root / "resources/app" if (root / "resources/app/product.json").is_file() else root
        if (resources / "product.json").is_file():
            app_dir = resources
            break

if not app_dir:
    print(json.dumps({"found": False}))
    raise SystemExit(0)

vscode_dir = app_dir / "out/vs/code"
paths = [
    vscode_dir / "electron-sandbox/workbench/workbench.html",
    vscode_dir / "electron-sandbox/workbench/workbench.esm.html",
    vscode_dir / "electron-browser/workbench/workbench.html",
]
print(json.dumps({
    "found": True,
    "product_json": str(app_dir / "product.json"),
    "workbench_paths": [str(p) for p in paths if p.is_file()],
    "settings_path": str(settings),
}))
PY
}

PATHS_JSON="$(resolve_paths)"
FOUND="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("found", False))' "$PATHS_JSON")"

if [[ "$FOUND" != "True" ]]; then
  echo "VS Code installation not found."
else
  PRODUCT_JSON="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["product_json"])' "$PATHS_JSON")"
  SETTINGS_PATH="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["settings_path"])' "$PATHS_JSON")"
  WORKBENCH_PATHS_JSON="$(python3 -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1])["workbench_paths"]))' "$PATHS_JSON")"

  maybe_sudo() {
    if [[ ! -w "$PRODUCT_JSON" && "${EUID:-$(id -u)}" -ne 0 ]]; then
      exec sudo -E "$0" $( [[ "$INSIDERS" -eq 1 ]] && echo --insiders )
    fi
  }

  echo "==> Removing workbench patch"
  maybe_sudo
  python3 - "$PRODUCT_JSON" "$WORKBENCH_PATHS_JSON" <<'PY'
import base64, hashlib, json, pathlib, re, sys

product_path = pathlib.Path(sys.argv[1])
paths = [pathlib.Path(p) for p in json.loads(sys.argv[2])]
patch_re = re.compile(r"<!-- !! VSCODE-CUSTOM-CSS-SESSION-ID [\w-]+ !! -->\s*")
block_re = re.compile(r"<!-- !! VSCODE-CUSTOM-CSS-START !! -->[\s\S]*?<!-- !! VSCODE-CUSTOM-CSS-END !! -->\s*")

restored = []
for path in paths:
    if not path.is_file():
        continue
    html = path.read_text(encoding="utf-8")
    if "VSCODE-CUSTOM-CSS-START" not in html:
        continue
    html = patch_re.sub("", html)
    html = block_re.sub("", html)
    path.write_text(html, encoding="utf-8")
    restored.append(path)
    print(f"    restored {path}")

if restored:
    app_dir = product_path.parent
    product = product_path.read_text(encoding="utf-8")
    for wb_path in restored:
        digest = base64.b64encode(hashlib.sha256(wb_path.read_bytes()).digest()).decode().rstrip("=")
        rel = wb_path.relative_to(app_dir).as_posix()
        key = rel[4:] if rel.startswith("out/") else rel
        product = re.sub(re.escape(f'"{key}"') + r':\s*"[^"]+"', f'"{key}": "{digest}"', product)
    product_path.write_text(product, encoding="utf-8")
else:
    print("    no glass patch found")
PY
fi

if [[ "${SETTINGS_PATH:-}" != "" && -f "${SETTINGS_PATH:-}" ]]; then
  echo "==> Cleaning settings.json"
  python3 - "$SETTINGS_PATH" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for key in (
    "vscode_custom_css.imports",
    "vscode_custom_css.statusbar",
    "workbench.colorCustomizations",
    "workbench.colorTheme",
    "window.titleBarStyle",
):
    data.pop(key, None)
path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
print("    Custom CSS settings removed")
PY
fi

echo "==> Removing theme files"
if [[ -d "$THEME_DIR" ]]; then
  rm -rf "$THEME_DIR"
  echo "    $THEME_DIR removed"
fi

echo ""
echo "Restart VS Code. Restore settings from settings.json.bak-glass-theme if needed."
echo ""
