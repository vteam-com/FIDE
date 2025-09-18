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

### 2. Pull a Coding Model

Pull a model optimized for coding tasks:

```bash
# Recommended for coding assistance
ollama pull codellama

# Alternative models
ollama pull llama2          # General purpose
ollama pull mistral         # Fast and capable
ollama pull deepseek-coder  # Specialized for coding
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
   - **Ask AI**: General coding questions
   - **Explain Code**: Get explanations for code snippets
   - **Generate Code**: Create new code based on descriptions
   - **Refactor Code**: Improve existing code

## 🔧 Configuration

### Changing the Model

To use a different model, edit `lib/services/ai_service.dart`:

```dart
static const String _defaultModel = 'your-preferred-model';
```

Available models depend on what you've pulled with Ollama.

### Troubleshooting

**Connection Issues:**
- Ensure Ollama is running: `ollama serve`
- Check if the model is available: `ollama list`
- Verify the model is pulled: `ollama pull <model-name>`

**Performance:**
- Smaller models (like `llama2:7b`) are faster but less capable
- Larger models (like `codellama:13b`) are more accurate but slower
- Consider your hardware capabilities when choosing models

## 📋 Supported Models

| Model | Size | Best For | Command |
|-------|------|----------|---------|
| codellama | 7B/13B | Code generation, refactoring | `ollama pull codellama` |
| llama2 | 7B/13B | General coding assistance | `ollama pull llama2` |
| mistral | 7B | Fast responses, general tasks | `ollama pull mistral` |
| deepseek-coder | 6B | Code-specific tasks | `ollama pull deepseek-coder` |

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
