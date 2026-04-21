#!/usr/bin/env bash
# run_harness.sh — Compile vt_harness.pas and regenerate Pascal baseline fixtures.
#
# Run this script whenever you need to update the baseline JSON files.
# Requires:  fpc (Free Pascal Compiler) ≥ 3.x
#
# Usage (from any directory):
#   bash pascal-tests/run_harness.sh
#
# The generated fixtures are committed to the repository.  A diff in any
# fixture file without a corresponding intentional change to the Pascal source
# is a red flag — investigate before merging.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AY_FIXTURES="$REPO_ROOT/crates/vti-ay/tests/fixtures/pascal-baselines"
CORE_FIXTURES="$REPO_ROOT/crates/vti-core/tests/fixtures/pascal-baselines"

# ─── Prerequisites ──────────────────────────────────────────────────────────
if ! command -v fpc >/dev/null 2>&1; then
  echo "ERROR: fpc (Free Pascal Compiler) not found." >&2
  echo "  On Ubuntu:  sudo apt-get install fp-compiler" >&2
  echo "  On macOS:   brew install fpc" >&2
  exit 1
fi

echo "FPC version: $(fpc -iV)"

# ─── Compile ────────────────────────────────────────────────────────────────
cd "$SCRIPT_DIR"
echo "Compiling vt_harness.pas ..."
fpc -Mdelphi -O2 -v0 vt_harness.pas

# ─── Create output directories ──────────────────────────────────────────────
mkdir -p "$AY_FIXTURES"
mkdir -p "$CORE_FIXTURES"

# ─── Generate fixtures ──────────────────────────────────────────────────────
echo "Generating AY fixtures ..."
./vt_harness noise_lfsr      > "$AY_FIXTURES/noise_lfsr.json"
./vt_harness envelopes        > "$AY_FIXTURES/envelope_shapes.json"
./vt_harness level_tables     > "$AY_FIXTURES/level_tables.json"

echo "Generating core fixtures ..."
./vt_harness pt3_vol          > "$CORE_FIXTURES/pt3_vol.json"
./vt_harness note_tables       > "$CORE_FIXTURES/note_tables.json"
./vt_harness pattern_basic     > "$CORE_FIXTURES/pattern_play_basic.json"
./vt_harness pattern_envelope  > "$CORE_FIXTURES/pattern_play_envelope.json"
./vt_harness pattern_arpeggio  > "$CORE_FIXTURES/pattern_play_arpeggio.json"
./vt_harness song_timing       > "$CORE_FIXTURES/song_timing.json"
./vt_harness prepare_zx_sqt   > "$CORE_FIXTURES/prepare_zx_sqt.json"
./vt_harness prepare_zx_fls   > "$CORE_FIXTURES/prepare_zx_fls.json"

echo ""
echo "Fixtures written to:"
echo "  $AY_FIXTURES/"
echo "  $CORE_FIXTURES/"

# ─── Validate JSON ──────────────────────────────────────────────────────────
if command -v python3 >/dev/null 2>&1; then
  echo ""
  echo "Validating JSON ..."
  for f in "$AY_FIXTURES"/*.json "$CORE_FIXTURES"/*.json; do
    python3 -m json.tool "$f" >/dev/null
    echo "  VALID: $(basename "$f")"
  done
fi

echo ""
echo "Done.  Review the diff and commit the updated fixtures."
