# AI Panel Setup Guide

The FIDE IDE now includes an AI Assistant panel that works with local Ollama models, providing AI-powered coding assistance without requiring external API keys.

## 🚀 Quick Setup

### 1. Install Ollama

Download and install Ollama from: https://ollama.ai/download

**macOS:**
```bash
brew install ollama
```

**Linux:**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

**Windows:**
Download the installer from the Ollama website.

### 2. Download a Model

FIDE downloads the model for you: the AI panel's setup offers **Download Model**, and picking another model in the panel's model menu downloads it. To download one yourself:

```bash
ollama pull mimo-v2.6:9b
```

### 3. Start Ollama

Ollama starts automatically when you run a model, but you can also start it manually:

```bash
ollama serve
```

The service will be available at `http://localhost:11434`

## 🎯 Using the AI Panel

1. **Open FIDE** and load a Flutter project
2. **Select a file** in the file explorer
3. **Click the "AI" tab** in the right panel
4. **Choose an action** from the dropdown:
   - **Ask AI**: Answers questions about your code, and makes the
     changes you ask for (explain, generate or refactor code) by editing
     the project files itself
   - **Fix Build**: Fixes the last failed build. With a project open, the
     model reads and edits project files itself (list, read, replace and
     write files, then rebuild for the platform selected in the Execute
     panel) until the build passes; open editor tabs reload as files
     change. The model can only touch files inside the project.

## 🔧 Configuration

### Changing the Model

Pick the model in the menu at the bottom right of the AI panel. Each one shows the memory it needs; the one in use is checked, and picking one not downloaded yet downloads it. FIDE remembers your choice.

### Troubleshooting

**Connection Issues:**
- Ensure Ollama is running: `ollama serve`
- Check if the model is available: `ollama list`
- Verify the model is pulled: `ollama pull <model-name>`

**Performance:**
- A model answers slowly when it doesn't fit in memory: pick one your computer has the memory for

## 📋 Supported Models

The models FIDE offers all edit files through Ollama tool calling. Each was measured on FIDE's agent benchmark, where the AI answers questions, renames code, adds a feature and fixes a broken build in a Flutter app.

| Model | Download | Memory | Best For |
|-------|----------|--------|----------|
| MiMo 9B (`mimo-v2.6:9b`) | 7–9 GB | 16 GB+ | Default: half Qwen3 Coder's memory and about as fast, a little less reliable on multi-file edits |
| Qwen3 Coder 30B (`qwen3-coder:30b`) | 19 GB | 32 GB+ | The most reliable edits, and the fastest writer |
| Qwen 3.8 27B (`qwen3.8:27b`) | 18 GB | 32 GB+ | Questions about a large project; slower |

## 🔒 Privacy & Security

- All AI processing happens locally on your machine
- No code or data is sent to external servers
- Conversations are stored only in memory during the session
- No API keys or external accounts required

## 🆘 Getting Help

If you encounter issues:

1. Check that Ollama is running
2. Verify the model is downloaded
3. Ensure FIDE can connect to `localhost:11434`
4. Try restarting both Ollama and FIDE

The AI panel will show helpful error messages and setup instructions when Ollama is not available.
