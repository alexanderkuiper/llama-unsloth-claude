#!/bin/sh
set -e

MODEL_FILE="${MODEL_FILE}"
MODEL_PATH="/models/$MODEL_FILE"
MODEL_NAME="qwen"

apt-get update -y
apt-get install curl -y

ollama serve &

until curl -sf http://localhost:11434/api/tags > /dev/null; do
  sleep 1
done

if ! ollama list | grep -q "$MODEL_NAME"; then
  echo "FROM $MODEL_PATH" > /tmp/Modelfile
  ollama create "$MODEL_NAME" -f /tmp/Modelfile
fi

wait