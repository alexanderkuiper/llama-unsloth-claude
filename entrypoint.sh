#!/bin/bash
set -e

REPO=${HF_MODEL_REPO:-unsloth/Qwen3.6-35B-A3B-GGUF}
FILE=${HF_MODEL_FILE:-Qwen3.6-35B-A3B-UD-Q4_K_M.gguf}
MODEL_PATH="/models/$FILE"

# 1. Download if missing
if [ ! -f "$MODEL_PATH" ]; then
    echo "--- Model not found. Downloading $FILE ---"
    hf download "$REPO" --include "$FILE" --local-dir /models
fi

# 2. Build llama.cpp if needed
if [ ! -f "/opt/llama.cpp/build/bin/llama-server" ]; then
    echo "--- Compiling llama.cpp ---"
    cd /opt/llama.cpp && cmake -B build -DGGML_CUDA=ON && cmake --build build --config Release -j$(nproc)
fi

# 3. Start Server
echo "--- Starting Engine ---"
/opt/llama.cpp/build/bin/llama-server \
    -m "$MODEL_PATH" \
    --host 0.0.0.0 --port 8080 \
    --n-gpu-layers 999 \
    --ctx-size 131072 \
    --cache-type-k q8_0 \
    --cache-type-v q8_0 \
    --flash-attn on