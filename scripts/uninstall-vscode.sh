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
    print(json.dumps({"found": False, "settings_path": str(settings)}))
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
    "workbench_paths": [str(p) for p in paths],
    "settings_path": str(settings),
}))
PY
}

PATHS_JSON="$(resolve_paths)"
FOUND="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("found", False))' "$PATHS_JSON")"
SETTINGS_PATH="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("settings_path", ""))' "$PATHS_JSON")"

if [[ "$FOUND" != "True" ]]; then
  echo "VS Code installation not found (will still clean settings/theme files if present)."
else
  PRODUCT_JSON="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["product_json"])' "$PATHS_JSON")"
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

def restore_from_backup(target: pathlib.Path) -> bool:
    parent = target.parent
    if not parent.is_dir():
        return False
    # Prefer bak matching this filename
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
    if not path.is_file() and not path.parent.is_dir():
        continue
    if path.is_file() and "VSCODE-CUSTOM-CSS-START" not in path.read_text(encoding="utf-8"):
        # Still try backup restore if CSP was stripped without markers somehow
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
fi

BACKUP="${SETTINGS_PATH}.bak-glass-theme"
echo "==> Cleaning settings.json"
if [[ -n "$SETTINGS_PATH" && -f "$BACKUP" ]]; then
  cp "$BACKUP" "$SETTINGS_PATH"
  echo "    Restored settings from settings.json.bak-glass-theme"
elif [[ -n "$SETTINGS_PATH" && -f "$SETTINGS_PATH" ]]; then
  python3 - "$SETTINGS_PATH" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for key in (
    "vscode_custom_css.imports",
    "vscode_custom_css.statusbar",
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
echo "Restart VS Code."
if [[ -n "$SETTINGS_PATH" ]]; then
  echo "Backup kept at: $BACKUP"
fi
echo ""
