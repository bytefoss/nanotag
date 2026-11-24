#!/usr/bin/env bash
#
# Build the nice!nano Fast Pair firmware -> build/nanotag.uf2
#
# Provide your Fast Pair credentials one of two ways:
#   1) Copy secrets.env.example to secrets.env and paste your values in (secrets.env is gitignored), or
#   2) export FP_MODEL_ID and FP_ANTI_SPOOFING_KEY in your shell.
#
# Run from inside the NCS v3.2.0 build shell (Option A: nrfutil toolchain shell; Option B: this script
# sources env.sh for you if west isn't already on PATH).
#
set -eo pipefail
cd "$(dirname "$0")"

# 1) Credentials
[ -f secrets.env ] && source ./secrets.env
if [ -z "${FP_MODEL_ID:-}" ] || [ -z "${FP_ANTI_SPOOFING_KEY:-}" ]; then
  echo "Missing Fast Pair credentials."
  echo "  Copy secrets.env.example -> secrets.env and fill in FP_MODEL_ID + FP_ANTI_SPOOFING_KEY,"
  echo "  or export them in your shell. (secrets.env is gitignored; never commit real values.)"
  exit 1
fi

# 2) Build environment (Option B convenience: source env.sh if west isn't available yet)
if ! command -v west >/dev/null 2>&1 && [ -f env.sh ]; then
  source ./env.sh
fi
if ! command -v west >/dev/null 2>&1; then
  echo "No NCS build environment on PATH. Enter the build shell first:"
  echo "  Option A (nrfutil): nrfutil sdk-manager toolchain launch --ncs-version v3.2.0 --shell"
  echo "  Option B (manual) : source env.sh"
  exit 1
fi

# 3) Optional local identity override (gitignored): applied on top of prj.conf if present.
extra_args=()
[ -f local.conf ] && extra_args+=("-Dnanotag_EXTRA_CONF_FILE=$(pwd)/local.conf")

# 4) Build + pack
west build -p always -b promicro_nrf52840/nrf52840/uf2 -d build nanotag -- \
  -DSB_CONFIG_BT_FAST_PAIR_MODEL_ID="$FP_MODEL_ID" \
  -DSB_CONFIG_BT_FAST_PAIR_ANTI_SPOOFING_PRIVATE_KEY="\"$FP_ANTI_SPOOFING_KEY\"" \
  -Dnanotag_CONFIG_BT_CTLR_TX_PWR_PLUS_8=y \
  "${extra_args[@]}"
python3 make_uf2.py

echo
echo "Built: build/nanotag.uf2"
echo "Flash: double-tap RESET, then copy build/nanotag.uf2 onto the NICENANO drive (macOS: cp -X)."
