#!/usr/bin/env bash
#
# Project 4 — Ethereum Wallet : one-shot environment setup
# ---------------------------------------------------------
# A Solidity/Foundry project has no Python venv. The equivalent "virtual
# environment" is a pinned Foundry toolchain plus project-local dependency
# libraries under ./lib. This script provisions all of that reproducibly so
# the project builds and tests the same way on every student's laptop.
#
# What it does:
#   1. Verifies prerequisites (curl, git).
#   2. Installs the Foundry toolchain (forge/cast/anvil) via foundryup if missing.
#   3. Fetches the exact dependency versions used by the reference solution
#      into ./lib  (forge-std + OpenZeppelin contracts).
#   4. Builds the project and runs the test suite as a sanity check.
#
# Usage:
#   bash setup.sh              # full setup + build + test
#   bash setup.sh --no-test    # set up and build, skip the test run
#   bash setup.sh --help
#
# Supported platforms: macOS, Linux, and Windows via WSL or Git Bash.
#
set -euo pipefail

# ----------------------------- pinned versions -----------------------------
# These match the reference solution. Bump them deliberately, not by accident.
FORGE_STD_VERSION="v1.11.0"
OZ_VERSION="v5.4.0"
# Foundry channel: "stable" (recommended) or "nightly". Override with FOUNDRY_VERSION.
FOUNDRY_VERSION="${FOUNDRY_VERSION:-stable}"
# ---------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT_DIR/lib"
RUN_TESTS=1

# --- pretty logging --------------------------------------------------------
if [ -t 1 ]; then
  BOLD="$(printf '\033[1m')"; GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"; RED="$(printf '\033[31m')"; RESET="$(printf '\033[0m')"
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi
info()  { printf '%s==>%s %s\n' "$GREEN$BOLD" "$RESET" "$*"; }
warn()  { printf '%sWARN:%s %s\n' "$YELLOW$BOLD" "$RESET" "$*"; }
err()   { printf '%sERROR:%s %s\n' "$RED$BOLD" "$RESET" "$*" >&2; }

# --- args ------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --no-test) RUN_TESTS=0 ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) err "unknown option: $arg"; exit 2 ;;
  esac
done

# --- 0. platform check -----------------------------------------------------
case "$(uname -s)" in
  Darwin) info "Detected macOS." ;;
  Linux)  info "Detected Linux / WSL." ;;
  MINGW*|MSYS*|CYGWIN*)
    warn "Detected Windows shell. Foundry works best under WSL2; continuing under Git Bash." ;;
  *) warn "Unrecognized platform '$(uname -s)'. Proceeding, but you may need to install Foundry manually." ;;
esac

# --- 1. prerequisites ------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1 || { err "missing required tool: $1 — please install it and re-run."; exit 1; }; }
need curl
need git

# --- 2. Foundry toolchain --------------------------------------------------
# Make sure ~/.foundry/bin is on PATH for this shell even right after install.
export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  info "Foundry not found — installing via foundryup..."
  curl -L https://foundry.paradigm.xyz | bash
  export PATH="$HOME/.foundry/bin:$PATH"
  if ! command -v foundryup >/dev/null 2>&1; then
    err "foundryup did not land on PATH. Open a new terminal (so your shell profile loads ~/.foundry/bin) and re-run: bash setup.sh"
    exit 1
  fi
  foundryup --install "$FOUNDRY_VERSION"
else
  info "Foundry present ($(forge --version 2>/dev/null | head -1)). Ensuring it's up to date..."
  if command -v foundryup >/dev/null 2>&1; then
    foundryup --install "$FOUNDRY_VERSION" || warn "foundryup update failed; continuing with the installed version."
  fi
fi

info "forge: $(forge --version | head -1)"

# --- 3. project-local dependencies (./lib) ---------------------------------
mkdir -p "$LIB_DIR"

fetch_lib() {
  local name="$1" repo="$2" ref="$3" dest
  dest="$LIB_DIR/$name"
  if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    info "lib/$name already present — skipping (delete the folder to re-fetch)."
    return
  fi
  info "Fetching $name @ $ref ..."
  rm -rf "$dest"
  git clone --quiet --depth 1 --branch "$ref" "$repo" "$dest"
  rm -rf "$dest/.git"   # keep it a plain vendored copy, not a nested git repo
}

fetch_lib "forge-std"            "https://github.com/foundry-rs/forge-std.git"            "$FORGE_STD_VERSION"
fetch_lib "openzeppelin-contracts" "https://github.com/OpenZeppelin/openzeppelin-contracts.git" "$OZ_VERSION"

# --- 4. build + test -------------------------------------------------------
cd "$ROOT_DIR"
info "Building..."
forge build

if [ "$RUN_TESTS" -eq 1 ]; then
  info "Running tests (skeletons start failing until you fill in the MCQ answers)..."
  # Don't let expected skeleton failures abort the script.
  forge test || warn "Some tests failed — expected while checkpoints are unsolved. Run 'forge test --mc Checkpoint0' as you go."
fi

cat <<EOF

${GREEN}${BOLD}Environment ready.${RESET}

  Toolchain : $(forge --version | head -1)
  Libraries : lib/forge-std ($FORGE_STD_VERSION), lib/openzeppelin-contracts ($OZ_VERSION)

Next steps:
  forge build                          # compile
  forge test --mc Checkpoint0          # run checkpoint 0 tests
  forge test --mc Checkpoint1
  forge test --mc Checkpoint2
  forge test                           # run everything

See README.md for the checkpoint instructions.
EOF
