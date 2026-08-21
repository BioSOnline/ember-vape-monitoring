#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_PATH="${1:-$SCRIPT_DIR/runs/detect/train/weights/best.pt}"
TARGET_PATH="${2:-$SCRIPT_DIR/assets/models/puff_detection.tflite}"

cd "$SCRIPT_DIR"

python3 export.py --model "$MODEL_PATH" --target "$TARGET_PATH" --format tflite --int8
