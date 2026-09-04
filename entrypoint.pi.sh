#!/bin/sh
set -eu

MODEL_ID="${MODEL_FILE%.gguf}"
MODEL_NAME="${MODEL_REPO##*/} (Local)"
MAX_TOKENS="${MAX_TOKENS:-8192}"

mkdir -p /root/.pi/agent

# Ensure the MCP extension package is installed for pi
if [ ! -d /root/.pi/agent/npm/node_modules/pi-mcp-extension ]; then
  pi install npm:pi-mcp-extension
fi

if [ ! -d /root/.pi/agent/npm/node_modules/pi-plan ]; then
  pi install npm:pi-plan
fi

cat > /root/.pi/agent/mcp.json <<EOF
{
  "mcpServers": {
    "vault": {
      "transport": "streamable-http",
      "url": "http://192.168.0.101:8765/mcp",
      "lifecycle": "eager",
      "headers": { "Authorization": "Bearer ${VAULT_MCP_KEY}" }
    }
  }
}
EOF

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

pi update --self 
exec tail -f /dev/null