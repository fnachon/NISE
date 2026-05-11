#!/usr/bin/env bash
# Build the NISE Apptainer/Singularity container.
#
# Usage:
#     bash build_container.sh                 # -> ./nise.sif  (rootless --fakeroot)
#     bash build_container.sh my_nise.sif     # custom output name
#     SUDO_BUILD=1 bash build_container.sh    # use `sudo` instead of --fakeroot

set -euo pipefail

OUT="${1:-nise.sif}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DEF="$SCRIPT_DIR/NISE.def"

cd "$SCRIPT_DIR"

echo "Removing existing .sif artifacts from the build context..."
rm -f ./*.sif ./*.sif.*

if command -v apptainer >/dev/null 2>&1; then
    RUNTIME=apptainer
elif command -v singularity >/dev/null 2>&1; then
    RUNTIME=singularity
else
    echo "ERROR: neither 'apptainer' nor 'singularity' found on PATH." >&2
    exit 1
fi

echo "Building $OUT using $RUNTIME from $DEF"

if [[ "${SUDO_BUILD:-0}" == "1" ]]; then
    sudo "$RUNTIME" build "$OUT" "$DEF"
else
    "$RUNTIME" build --fakeroot "$OUT" "$DEF"
fi

echo
echo "Done. Quick GPU check:"
echo "    $RUNTIME exec --nv $OUT python -c 'import torch; print(torch.cuda.is_available())'"
