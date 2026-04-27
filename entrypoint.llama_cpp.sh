#!/bin/bash
# set -e

# Use the variables from your .env
REPO=${MODEL_REPO}
FILE=${MODEL_FILE}
MODEL_PATH="/models/$FILE"

# 1. Check if the specific GGUF file exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "--- Model not found at $MODEL_PATH ---"
    echo "--- Downloading $FILE from $REPO ---"
    
    # --local-dir-use-symlinks False ensures the actual file is in /models
    hf download "$REPO" "$FILE" --local-dir /models
else
    echo "--- Model $FILE found! Skipping download. ---"
fi

# 2. Start the server
echo "--- Starting llama-server ---"
exec /app/llama-server \
    -m "$MODEL_PATH" \
    --host 0.0.0.0 --port 8080 \
    --n-gpu-layers "$N_GPU_LAYERS" \
    --ctx-size "$CTX_SIZE" \
    --flash-attn on