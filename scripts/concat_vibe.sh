#!/usr/bin/env sh
# Concatenate Vibe source fragments in order into one file (for kernel build).
# Usage: concat_vibe.sh <output_path> <input1> [input2 ...]
set -e
out="$1"
shift
mkdir -p "$(dirname "$out")"
cat "$@" > "$out"
