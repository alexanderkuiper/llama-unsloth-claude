#!/bin/bash
# set -e
REPO=${MODEL_REPO}
FILE=${MODEL_FILE}
MODEL_PATH="/models/$FILE"

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
# if [ ! -f "$MODEL_PATH" ]; then
#     echo "--- Model not found at $MODEL_PATH ---"
#     echo "--- Downloading $FILE from $REPO ---"
#     hf download "$REPO" "$FILE" --local-dir /models
# else
#     echo "--- Model $FILE found! Skipping download. ---"
# fi

# 1b. Only bother with the mmproj (vision projector) file if MMPROJ_FILE is actually set.
#     Leave MMPROJ_FILE unset/commented in .env when you don't need image input —
#     this skips the download AND skips passing --mmproj to the server, freeing VRAM.
MMPROJ_ARGS=()
if [ -n "$MMPROJ_FILE" ]; then
    MMPROJ_PATH="/models/$MMPROJ_FILE"
    # if [ ! -f "$MMPROJ_PATH" ]; then
    #     echo "--- mmproj not found at $MMPROJ_PATH ---"
    #     echo "--- Downloading $MMPROJ_FILE from $REPO ---"
    #     hf download "$REPO" "$MMPROJ_FILE" --local-dir /models
    # else
    #     echo "--- mmproj $MMPROJ_FILE found! Skipping download. ---"
    # fi
    MMPROJ_ARGS=(--mmproj "$MMPROJ_PATH")
else
    echo "--- MMPROJ_FILE not set, skipping vision projector (text-only mode) ---"
fi

# 2. Start the server
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
    --no-mmap \
    --mlock