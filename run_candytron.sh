#!/usr/bin/env bash
# run_candytron.sh — Startar hela Candytron-stacken i tre terminaler.
#
# Användning:
#   bash run_candytron.sh [flaggor]
#
# Flaggor:
#   --ned2-task   <task>   Pixi-task för NED2     (default: sim)
#   --reachy-task <task>   Pixi-task för Reachy   (default: reachy)
#   --daemon-task <task>   Pixi-task för daemon   (default: daemon-sim)
#   --headless             Kör MuJoCo utan fönster (MUJOCO_GL=egl)
#   --no-reachy            Kör bara NED2 + daemon
#   --timeout     <sek>    Timeout för NED2 och daemon (default: 60)
#   --help                 Visa denna hjälptext

set -e

# ── Standardvärden ───────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NED2_DIR="$SCRIPT_DIR/simulationCandytron8000"
REACHY_DIR="$SCRIPT_DIR/simulationCandytronReachy"

NED2_TASK="sim"
REACHY_TASK="reachy"
DAEMON_TASK="daemon-sim"
HEADLESS=false
NO_REACHY=false
TIMEOUT=60

NED2_PORT=8765
DAEMON_PORT=8000
POLL_INTERVAL=2

# ── Flaggparsning ────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ned2-task)   NED2_TASK="$2";   shift 2 ;;
        --reachy-task) REACHY_TASK="$2"; shift 2 ;;
        --daemon-task) DAEMON_TASK="$2"; shift 2 ;;
        --headless)    HEADLESS=true;    shift   ;;
        --no-reachy)   NO_REACHY=true;   shift   ;;
        --timeout)     TIMEOUT="$2";     shift 2 ;;
        --help)
            sed -n '/^# Användning/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "[run] Okänd flagga: $1 — kör med --help för hjälp."; exit 1 ;;
    esac
done

# ── Plattformsdetektering ────────────────────────────────────────────────────

detect_terminal() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "mac"
    elif command -v kitty     &>/dev/null; then echo "kitty"
    elif command -v alacritty &>/dev/null; then echo "alacritty"
    elif command -v gnome-terminal &>/dev/null; then echo "gnome-terminal"
    elif command -v xterm     &>/dev/null; then echo "xterm"
    else
        echo "[run] Inget terminalprogram hittades." >&2
        exit 1
    fi
}

# Öppnar en ny terminal med given titel och kommando.
# Användning: open_terminal "Titel" "kommando som ska köras"
open_terminal() {
    local title="$1"
    local cmd="$2"
    local terminal
    terminal=$(detect_terminal)

    # Kommandot wrappas så att terminalen håller sig öppen vid fel.
    local wrapped="$cmd; echo; echo '[${title}] Process avslutad. Tryck Enter.'; read"

    case "$terminal" in
        mac)
            # Försök iTerm2 först, faller tillbaka på Terminal.app
            if osascript -e 'tell application "iTerm2" to version' &>/dev/null 2>&1; then
                osascript <<EOF
tell application "iTerm2"
    tell current window
        create tab with default profile
        tell current session
            set name to "$title"
            write text "$wrapped"
        end tell
    end tell
end tell
EOF
            else
                osascript <<EOF
tell application "Terminal"
    do script "$wrapped"
    set custom title of front window to "$title"
    activate
end tell
EOF
            fi
            ;;
        kitty)
            kitty --title "$title" bash -c "$wrapped" &
            ;;
        alacritty)
            alacritty --title "$title" -e bash -c "$wrapped" &
            ;;
        gnome-terminal)
            gnome-terminal --title="$title" -- bash -c "$wrapped"
            ;;
        xterm)
            xterm -title "$title" -e bash -c "$wrapped" &
            ;;
    esac
}

# ── Hälsokoll med timeout ────────────────────────────────────────────────────

wait_for_port() {
    local name="$1"
    local url="$2"
    local elapsed=0

    echo "[run] Väntar på $name..."
    until curl -sf "$url" > /dev/null 2>&1; do
        sleep $POLL_INTERVAL
        elapsed=$((elapsed + POLL_INTERVAL))
        if [ $elapsed -ge "$TIMEOUT" ]; then
            echo "[run] TIMEOUT: $name svarade inte inom ${TIMEOUT}s — avbryter."
            exit 1
        fi
        echo "[run] Väntar på $name... (${elapsed}s / ${TIMEOUT}s)"
    done
    echo "[run] $name redo!"
}

wait_for_daemon() {
    local elapsed=0
    echo "[run] Väntar på Reachy daemon..."
    until curl -sf "http://localhost:$DAEMON_PORT" > /dev/null 2>&1 || \
          grep -q "Daemon started successfully" /tmp/reachy_daemon.log 2>/dev/null; do
        sleep $POLL_INTERVAL
        elapsed=$((elapsed + POLL_INTERVAL))
        if [ $elapsed -ge "$TIMEOUT" ]; then
            echo "[run] TIMEOUT: Daemon svarade inte inom ${TIMEOUT}s — avbryter."
            exit 1
        fi
        echo "[run] Väntar på daemon... (${elapsed}s / ${TIMEOUT}s)"
    done
    echo "[run] Daemon redo!"
}

# ── Bygg miljövariabler ──────────────────────────────────────────────────────

MUJOCO_ENV=""
if $HEADLESS; then
    MUJOCO_ENV="MUJOCO_GL=egl "
    echo "[run] Headless-läge aktiverat (MUJOCO_GL=egl)"
fi

# ── Starta stacken ───────────────────────────────────────────────────────────

echo "[run] Startar NED2 ($NED2_TASK)..."
open_terminal "NED2 Sim" "cd '$NED2_DIR' && ${MUJOCO_ENV}pixi run $NED2_TASK"

wait_for_port "NED2 API" "http://localhost:$NED2_PORT/health"

rm -f /tmp/reachy_daemon.log
echo "[run] Startar Reachy daemon ($DAEMON_TASK)..."
open_terminal "Reachy Daemon" \
    "cd '$REACHY_DIR' && ${MUJOCO_ENV}pixi run $DAEMON_TASK 2>&1 | tee /tmp/reachy_daemon.log"

wait_for_daemon

if ! $NO_REACHY; then
    echo "[run] Startar Reachy node ($REACHY_TASK)..."
    open_terminal "Reachy Node" "cd '$REACHY_DIR' && pixi run $REACHY_TASK"
fi

echo "[run] Alla processer igång."
