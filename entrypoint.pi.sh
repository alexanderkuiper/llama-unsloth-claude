#!/bin/sh
set -eu

MODEL_ID="${MODEL_FILE%.gguf}"
MODEL_NAME="${MODEL_REPO##*/} (Local)"

mkdir -p /root/.pi/agent
cat > /root/.pi/agent/models.json <<EOF
{
  "providers": {
    "llama-local": {
      "baseUrl": "http://llm:8080/v1",
      "api": "openai-completions",
      "apiKey": "dummy",
      "models": [
        {
          "id": "${MODEL_ID}",
          "name": "${MODEL_NAME}",
          "reasoning": true,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": ${CTX_SIZE},
          "maxTokens": ${MAX_TOKENS}
        }
      ]
    }
  }
}
EOF

exec pi --provider llama-local --model "${MODEL_ID}"