#!/bin/bash
# set -e
REPO=${MODEL_REPO}
FILE=${MODEL_FILE}
MMPROJ_FILE=${MMPROJ_FILE:-mmproj-F16.gguf}
MODEL_PATH="/models/$FILE"
MMPROJ_PATH="/models/$MMPROJ_FILE"

# Performance tuning (overridable via .env, with sane fallbacks)
N_GPU_LAYERS=${N_GPU_LAYERS:--1}
CTX_SIZE=${CTX_SIZE:-32768}
N_CPU_MOE=${N_CPU_MOE:-12}
FLASH_ATTN=${FLASH_ATTN:-on}
CACHE_TYPE_K=${CACHE_TYPE_K:-q8_0}
CACHE_TYPE_V=${CACHE_TYPE_V:-q8_0}
THREADS=${THREADS:-8}
BATCH_SIZE=${BATCH_SIZE:-2048}
UBATCH_SIZE=${UBATCH_SIZE:-512}

# 1. Check if the specific GGUF file exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "--- Model not found at $MODEL_PATH ---"
    echo "--- Downloading $FILE from $REPO ---"
    hf download "$REPO" "$FILE" --local-dir /models
else
    echo "--- Model $FILE found! Skipping download. ---"
fi

# 1b. Check if the mmproj (vision projector) file exists
if [ ! -f "$MMPROJ_PATH" ]; then
    echo "--- mmproj not found at $MMPROJ_PATH ---"
    echo "--- Downloading $MMPROJ_FILE from $REPO ---"
    hf download "$REPO" "$MMPROJ_FILE" --local-dir /models
else
    echo "--- mmproj $MMPROJ_FILE found! Skipping download. ---"
fi

# 2. Start the server
echo "--- Starting llama-server ---"
exec /app/llama-server \
    -m "$MODEL_PATH" \
    --mmproj "$MMPROJ_PATH" \
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
    --no-mmap \
    --mlock