# Candytron 8000

> Multi-robot, multi-agent candy dispenser driven by voice, AI, and simulation

You ask for a candy using your voice. The system hears you, understands what you want, and a robot arm picks it up and delivers it to you — all inside a MuJoCo physics simulation.

---

## Architecture

Two separate processes communicate via a REST API:

```
┌─────────────────────────────────────┐     HTTP :8765     ┌──────────────────────────────────┐
│   simulationCandytronReachy         │ ◄────────────────► │   simulationCandytron8000        │
│                                     │                    │                                  │
│  PTT → STT → LLM → Confirmation     │                    │  NED2 arm + MuJoCo + YOLO        │
│  Piper TTS  |  Reachy Mini SDK      │                    │  REST API (/pick /status …)      │
└─────────────────────────────────────┘                    └──────────────────────────────────┘
     Reachy Mini — listens & decides                            NED2 — sees & picks
```

The **Reachy node** handles voice interaction, decision-making, and coordination with the arm. The **NED2 node** runs the MuJoCo simulation, YOLO detection, AprilTag calibration, and inverse kinematics.

### Interaction Flow

```
You speak  →  Whisper transcribes  →  LLM selects candy  →  NED2 calibrates & picks  →  Piper confirms
```

---

## Requirements

- [pixi](https://pixi.sh) — package manager (handles all Python dependencies)
- `libcairo2-dev` — system library required by the Reachy Mini SDK

```bash
sudo apt install libcairo2-dev   # Linux
brew install cairo               # macOS
```

---

## Installation

```bash
bash install_candytron.sh
```

The script installs both pixi environments in the correct order, checks for `cairo` first, and prompts for API keys.

---

## Running the System

```bash
bash run_candytron.sh
```

Opens three terminals in the correct startup order and waits for each process to respond before starting the next.

### Flags

| Flag | Effect |
|------|--------|
| *(none)* | Microphone input, Enter activates PTT |
| `--headless` | Run MuJoCo without a window (`MUJOCO_GL=egl`) |
| `--no-reachy` | Run only NED2 + daemon |
| `--ned2-task <task>` | Select pixi task for NED2 (default: `sim`) |
| `--reachy-task <task>` | Select pixi task for Reachy (default: `reachy`) |
| `--timeout <sec>` | Startup timeout in seconds (default: 60) |

### Manual Start

```bash
# Terminal 1 — NED2 simulation + API (port 8765)
cd simulationCandytron8000
pixi run sim

# Terminal 2 — Reachy daemon (MuJoCo bridge, port 8000)
cd simulationCandytronReachy
pixi run daemon-sim

# Terminal 3 — Reachy node
cd simulationCandytronReachy
pixi run reachy
```

---

## Key Technologies

| Technology | Use |
|------------|-----|
| **MuJoCo** | Physics simulation of robots and objects |
| **YOLO** | Real-time detection of candy objects |
| **AprilTags + PnP** | Camera calibration, pixel → 3D coordinate |
| **Inverse kinematics** | Joint angle planning for the pick motion |
| **faster-whisper** | Speech recognition, 9 languages, auto-detection |
| **LLM (Claude / Groq / Ollama)** | Intent understanding and candy selection logic |
| **Piper TTS** | Multilingual text-to-speech, runs fully locally |
| **FastAPI** | REST API between the Reachy and NED2 nodes |

### Language Support

Whisper automatically detects the spoken language and Piper switches voice accordingly.

Swedish · English · German · French · Finnish · Italian · Danish · Norwegian · Spanish

---

## Project Status

| Component | Status |
|-----------|--------|
| NED2 pick-and-place | Working |
| AprilTag calibration | Working |
| YOLO detection | Working |
| Reachy FSM + LLM | Working |
| Whisper STT (microphone) | Working |
| Multilingual TTS (Piper) | Working |
| Hybrid mode (mic + keyboard) | Implemented |
| Scene reset (`reset`) | Implemented |

---

## Subprojects

- [`simulationCandytron8000/`](simulationCandytron8000/README.md) — NED2 arm, MuJoCo, YOLO, IK, REST API
- [`simulationCandytronReachy/`](simulationCandytronReachy/README.md) — Reachy Mini, Whisper, LLM, Piper TTS

---

## License

The scripts in this repository are licensed under the **MIT License** — see [LICENSE](LICENSE).

The subprojects have their own licenses:
- `simulationCandytron8000/` — AGPL-3.0 (due to Ultralytics/YOLO)
- `simulationCandytronReachy/` — Apache 2.0

Third-party assets retain their original licenses:
- Reachy Mini 3D assets (Pollen Robotics) — see `simulationCandytron8000/assets/reachy_mini_assets/mjcf/LICENSE`
- NED2 URDF and mesh files (Niryo) — CC0 1.0 Universal (public domain)

---

## Acknowledgements

- **[Pollen Robotics](https://www.pollen-robotics.com/)** — Reachy Mini robot and `reachy-mini` Python SDK
- **[Google DeepMind](https://mujoco.org/)** — MuJoCo physics simulator
- **[Niryo](https://niryo.com/)** — NED2 URDF and kinematics data
- **[Ultralytics](https://github.com/ultralytics/ultralytics)** — YOLO object detection
- **[faster-whisper](https://github.com/SYSTRAN/faster-whisper)** by SYSTRAN — fast STT via CTranslate2
- **[Piper TTS](https://github.com/rhasspy/piper)** by Rhasspy — local neural text-to-speech
- **[Groq](https://groq.com/)** — ultra-fast LLM inference API
- **[pixi](https://pixi.sh/)** by prefix.dev — reproducible environment management
- **RISE — Research Institutes of Sweden** — research environment and support

---

*Eddie Karlsen*
