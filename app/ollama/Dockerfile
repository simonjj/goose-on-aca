FROM ollama/ollama:latest

# Set environment variables for Ollama
ENV OLLAMA_CONTEXT_LENGTH=32768
ENV OLLAMA_HOST=0.0.0.0:11434

# Create directories for model storage
RUN mkdir -p /root/.ollama

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Starting Ollama server..."\n\
ollama serve &\n\
sleep 5\n\
echo "Pulling required model: qwen3:14b"\n\
ollama pull qwen3:14b || echo "Failed to pull model, will continue"\n\
wait\n' > /start-ollama.sh && chmod +x /start-ollama.sh

# Expose the default Ollama port
EXPOSE 11434

# Use the startup script
CMD ["/start-ollama.sh"]