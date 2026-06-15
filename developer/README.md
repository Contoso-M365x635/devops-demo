# Developer environment README
# Open WebUI + Ollama local LLM stack

## Quick Start

```bash
# Start the stack
docker compose up -d

# Pull a model (first time only — ~2GB download)
docker exec ollama ollama pull phi3:mini

# Open the UI
start http://localhost:3000
```

## Stopping

```bash
docker compose down
```

## Models

| Model | Size | Command |
|---|---|---|
| phi3:mini (recommended) | 2.3GB | `docker exec ollama ollama pull phi3:mini` |
| llama3.2:1b (fastest) | 1.3GB | `docker exec ollama ollama pull llama3.2:1b` |
| mistral:7b (best quality) | 4GB | `docker exec ollama ollama pull mistral:7b` |

## Ports

| Service | URL |
|---|---|
| Open WebUI | http://localhost:3000 |
| Ollama API | http://localhost:11434 |
