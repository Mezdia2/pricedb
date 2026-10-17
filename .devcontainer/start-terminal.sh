#!/usr/bin/env bash
# Terminal-only Codespace: serves a web terminal (ttyd) on $PORT, right-aligned (RTL).
set -euo pipefail

PORT="${PORT:-7681}"
DIR="$HOME/.terminal-only"
mkdir -p "$DIR"

# 1) Install ttyd if missing (static binary from GitHub releases)
if ! command -v ttyd >/dev/null 2>&1; then
  case "$(uname -m)" in
    x86_64)  ASSET=ttyd.x86_64 ;;
    aarch64) ASSET=ttyd.aarch64 ;;
    *) echo "unsupported arch $(uname -m)"; exit 1 ;;
  esac
  sudo curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/$ASSET" -o /usr/local/bin/ttyd
  sudo chmod +x /usr/local/bin/ttyd
fi

# 2) Stop any previous instance
pkill -x ttyd 2>/dev/null || true
sleep 1

# 3) Build a custom index.html = ttyd's default page + RTL CSS
CLIENT_OPTS=(
  -t rendererType=dom
  -t fontSize=16
  -t "fontFamily=Vazirmatn, 'Noto Sans Mono', 'DejaVu Sans Mono', monospace"
  -t cursorBlink=true
  -t scrollback=10000
)
ttyd -p 17681 -i 127.0.0.1 "${CLIENT_OPTS[@]}" true >/dev/null 2>&1 &
TMP_PID=$!
for _ in $(seq 1 20); do curl -fs http://127.0.0.1:17681/ -o "$DIR/default.html" && break; sleep 0.3; done
kill "$TMP_PID" 2>/dev/null || true

python3 - "$DIR/default.html" "$DIR/index.html" <<'PY'
import sys
src, dst = sys.argv[1:3]
css = """<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;700&display=swap">
<style>
  html, body { background:#0d1117; margin:0; height:100%; }
  .xterm-rows > div { direction: rtl; text-align: right; }
  .xterm-rows { letter-spacing: 0 !important; }
</style>"""
html = open(src, encoding="utf-8").read()
open(dst, "w", encoding="utf-8").write(html.replace("</head>", css + "</head>", 1))
PY

# 4) Real server. Codespaces forwards the port as PRIVATE by default (GitHub login required).
#    Optional extra password: set TTYD_CRED="user:pass" (e.g. as a Codespaces secret).
AUTH=()
[ -n "${TTYD_CRED:-}" ] && AUTH=(-c "$TTYD_CRED")
cd "${WORKSPACE:-$PWD}"
exec ttyd -p "$PORT" -W "${AUTH[@]}" -I "$DIR/index.html" "${CLIENT_OPTS[@]}" bash -l
