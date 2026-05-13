#!/usr/bin/env bash
# =============================================================================
# install_candytron.sh — Installerar båda pixi-miljöerna för Candytron.
#
# VAD DETTA SCRIPT GÖR (i ordning):
#   1. Kontrollerar att pixi är installerat
#   2. Kontrollerar att systembibliotek (cairo) finns
#   3. Kör "pixi install" i simulationCandytron8000  (NED2 + YOLO)
#   4. Kör "setup.sh"    i simulationCandytronReachy (Reachy Mini SDK)
#
# VAD DETTA SCRIPT INTE GÖR:
#   - Installerar ingenting globalt utan att fråga (undantaget: brew/apt-check)
#   - Ändrar ingenting utanför de två projektmapparna
#   - Laddar ner något utöver vad pixi.toml-filerna specificerar
#   - Kräver root/sudo (utom för den manuella cairo-installationen som du gör själv)
#
# KÄLLKOD: Allt detta script gör syns nedan — inget dolt.
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NED2_DIR="$SCRIPT_DIR/simulationCandytron8000"
REACHY_DIR="$SCRIPT_DIR/simulationCandytronReachy"

# Färgkoder för läsbar output — bara estetik, påverkar inget beteende
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail() { echo -e "${RED}[FEL]${NC}   $*"; exit 1; }
info() { echo -e "        $*"; }

echo ""
echo "========================================"
echo "  Candytron — installation"
echo "========================================"
echo ""

# ── Steg 1: Kontrollera att pixi finns ──────────────────────────────────────
# pixi är pakethanteraren som används av båda projekten.
# Installationsguide om det saknas: https://pixi.sh
echo "[1/4] Kontrollerar pixi..."
if ! command -v pixi &>/dev/null; then
    fail "pixi hittades inte. Installera det via: curl -fsSL https://pixi.sh/install.sh | sh"
fi
ok "pixi $(pixi --version) hittades"

# ── Steg 2: Kontrollera systembibliotek (cairo) ──────────────────────────────
# cairo är ett C-bibliotek för vektorgrafiik. Det krävs för att bygga PyGObject
# (som Reachy Mini SDK beror på) från källkod. Utan det misslyckas pip-builden.
# Vi installerar INTE detta automatiskt — det kräver sudo och varierar per system.
echo ""
echo "[2/4] Kontrollerar systembibliotek..."

PLATFORM="$(uname)"
CAIRO_OK=false

if [[ "$PLATFORM" == "Darwin" ]]; then
    # macOS: cairo installeras via Homebrew (https://brew.sh)
    if command -v brew &>/dev/null && brew list cairo &>/dev/null 2>&1; then
        CAIRO_OK=true
        ok "cairo hittades (Homebrew)"
    else
        warn "cairo saknas på macOS."
        info "Kör följande och starta sedan om install-scriptet:"
        info ""
        info "  brew install cairo"
        info ""
        exit 1
    fi
else
    # Linux: letar efter cairo pkg-config-fil på standardplatser
    # pkg-config --exists returnerar 0 om paketet finns, annars 1
    if pkg-config --exists cairo 2>/dev/null; then
        CAIRO_OK=true
        ok "cairo hittades (system pkg-config)"
    elif dpkg -s libcairo2-dev &>/dev/null 2>&1; then
        CAIRO_OK=true
        ok "cairo hittades (libcairo2-dev)"
    else
        warn "libcairo2-dev saknas på Linux."
        info "Kör följande och starta sedan om install-scriptet:"
        info ""
        info "  sudo apt install libcairo2-dev"
        info ""
        exit 1
    fi
fi

# ── Steg 3: Installera NED2-miljön ──────────────────────────────────────────
# Kör enbart "pixi install" i NED2-mappen.
# pixi läser pixi.toml och laddar ner exakt de paket som listas där
# till en isolerad mapp (.pixi/envs/) — inget installeras globalt.
# Paketlistan finns i: simulationCandytron8000/pixi.toml
echo ""
echo "[3/4] Installerar NED2-miljön (simulationCandytron8000)..."
info "Paketlista: $NED2_DIR/pixi.toml"
info "Installeras till: $NED2_DIR/.pixi/envs/"
echo ""

if [ ! -d "$NED2_DIR" ]; then
    fail "Mappen $NED2_DIR hittades inte."
fi

cd "$NED2_DIR"
# pixi install laddar ner och installerar conda + pip-paket enligt pixi.toml
# Inget körs, inget startas — bara filer kopieras till .pixi/envs/
pixi install
ok "NED2-miljön installerad"

# ── Steg 4: Installera Reachy-miljön ────────────────────────────────────────
# Kör setup.sh i Reachy-mappen istället för "pixi install" direkt.
# setup.sh gör tre saker (se filen för detaljer):
#   a) Kör "pixi install" för conda-paket (cairo, gstreamer, pygobject m.m.)
#   b) Sätter PKG_CONFIG_PATH så att pip-builden av PyGObject hittar cairo
#   c) Verifierar att "import gi" fungerar efteråt
# Paketlista finns i: simulationCandytronReachy/pixi.toml
echo ""
echo "[4/4] Installerar Reachy-miljön (simulationCandytronReachy)..."
info "Paketlista: $REACHY_DIR/pixi.toml"
info "Installeras till: $REACHY_DIR/.pixi/envs/"
info "Körs via: $REACHY_DIR/setup.sh"
echo ""

if [ ! -d "$REACHY_DIR" ]; then
    fail "Mappen $REACHY_DIR hittades inte."
fi

if [ ! -f "$REACHY_DIR/setup.sh" ]; then
    fail "setup.sh saknas i $REACHY_DIR."
fi

cd "$REACHY_DIR"
bash setup.sh
ok "Reachy-miljön installerad"

# ── Klart ────────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
ok "Installation klar!"
echo "========================================"
echo ""
echo "  Starta simuleringen med:"
echo ""
echo "    bash $SCRIPT_DIR/run_candytron.sh"
echo ""
