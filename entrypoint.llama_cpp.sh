#!/bin/bash
set -euo pipefail   # fail fast; catch unset vars and pipe failures too

REPO=${MODEL_REPO:-}
FILE=${MODEL_FILE:?MODEL_FILE must be set}
MODEL_PATH="/models/$FILE"

N_GPU_LAYERS=${N_GPU_LAYERS:--1}
CTX_SIZE=${CTX_SIZE:-32768}
N_CPU_MOE=${N_CPU_MOE:-12}
FLASH_ATTN=${FLASH_ATTN:-on}
CACHE_TYPE_K=${CACHE_TYPE_K:-q8_0}
CACHE_TYPE_V=${CACHE_TYPE_V:-q8_0}
THREADS=${THREADS:-8}
BATCH_SIZE=${BATCH_SIZE:-2048}
UBATCH_SIZE=${UBATCH_SIZE:-512}

# --- Wait for the model file to actually be present & stable (fixes mount races) ---
WAIT_TIMEOUT=${MODEL_WAIT_TIMEOUT:-60}
elapsed=0
while [ ! -f "$MODEL_PATH" ]; do
    if [ "$elapsed" -ge "$WAIT_TIMEOUT" ]; then
        echo "--- ERROR: $MODEL_PATH not found after ${WAIT_TIMEOUT}s ---"
        exit 1
    fi
    echo "--- Waiting for $MODEL_PATH to appear (mount not ready?) [$elapsed/${WAIT_TIMEOUT}s] ---"
    sleep 2
    elapsed=$((elapsed + 2))
done
echo "--- Model $FILE found at $MODEL_PATH ---"

# --- Optional mmproj (vision projector) ---
MMPROJ_ARGS=()
if [ -n "${MMPROJ_FILE:-}" ]; then
    MMPROJ_PATH="/models/$MMPROJ_FILE"
    if [ ! -f "$MMPROJ_PATH" ]; then
        echo "--- ERROR: mmproj file $MMPROJ_PATH not found ---"
        exit 1
    fi
    MMPROJ_ARGS=(--mmproj "$MMPROJ_PATH")
else
    echo "--- MMPROJ_FILE not set, skipping vision projector (text-only mode) ---"
fi

echo "--- Starting llama-server ---"
exec /app/llama-server \
    -m "$MODEL_PATH" \
    "${MMPROJ_ARGS[@]}" \
    --host 0.0.0.0 --port 8080 \
    --n-gpu-layers "$N_GPU_LAYERS" \
    --ctx-size "$CTX_SIZE" \
    --n-cpu-moe "$N_CPU_MOE" \
    --parallel 1 \
    --flash-attn "$FLASH_ATTN" \
    --cache-type-k "$CACHE_TYPE_K" \
    --cache-type-v "$CACHE_TYPE_V" \
    --threads "$THREADS" \
    --batch-size "$BATCH_SIZE" \
    --ubatch-size "$UBATCH_SIZE" \
    --load-mode mmap