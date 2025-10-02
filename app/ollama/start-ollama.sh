#!/bin/bash
# filepath: \\wsl$\Ubuntu\home\simon\code\goose-on-aca\app\ollama\start-ollama.sh

set -e

# Default model if none specified
DEFAULT_MODEL="qwen2.5:14b"

# Function to start ollama and pull model (keeps running)
start_with_model() {
    local model="${1:-$DEFAULT_MODEL}"
    echo "Starting Ollama server..."
    ollama serve &
    
    # Wait for server to be ready
    echo "Waiting for Ollama server to be ready..."
    sleep 5
    
    # Try to pull the model
    echo "Pulling required model: $model"
    if ollama pull "$model"; then
        echo "Successfully pulled model: $model"
    else
        echo "Failed to pull model: $model, but server is running"
    fi
    
    echo "Ollama server is ready with model: $model"
    echo "Server will keep running... (Press Ctrl+C to stop)"
    wait
}

# Function to pull model and quit
pull_and_quit() {
    local model="${1:-$DEFAULT_MODEL}"
    echo "Starting Ollama server temporarily..."
    ollama serve &
    local server_pid=$!
    
    # Wait for server to be ready
    echo "Waiting for Ollama server to be ready..."
    sleep 5
    
    # Try to pull the model
    echo "Pulling model: $model"
    if ollama pull "$model"; then
        echo "Successfully pulled model: $model"
    else
        echo "Failed to pull model: $model"
    fi
    
    echo "Shutting down Ollama server..."
    kill $server_pid
    wait $server_pid 2>/dev/null || true
    echo "Model pull complete. Container will exit."
}

# Parse command line arguments
case "$1" in
    "serve")
        # Just start the server without pulling any model
        echo "Starting Ollama server only..."
        exec /bin/ollama serve
        ;;
    "start")
        # Start server and pull model (keeps running)
        model="${2:-$DEFAULT_MODEL}"
        start_with_model "$model"
        ;;
    "pull")
        # Pull model and quit
        model="${2:-$DEFAULT_MODEL}"
        pull_and_quit "$model"
        ;;
    "interactive"|"bash"|"shell")
        # Interactive bash shell
        exec /bin/bash
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [COMMAND] [MODEL]"
        echo ""
        echo "Commands:"
        echo "  serve              Start Ollama server only"
        echo "  start [MODEL]      Start server and pull model (keeps running)"
        echo "  pull [MODEL]       Pull model and exit (default: $DEFAULT_MODEL)"
        echo "  interactive        Start interactive bash shell"
        echo "  bash               Same as interactive"
        echo "  shell              Same as interactive"
        echo "  help               Show this help"
        echo "  [other]            Pass command directly to ollama"
        echo ""
        echo "Examples:"
        echo "  $0 start llama2:7b    # Start server with model"
        echo "  $0 pull qwen2.5:32b   # Pull model and exit"
        echo "  $0 serve              # Just run server"
        echo "  $0 interactive        # Debug shell"
        ;;
    "")
        # Default behavior: start with default model (keeps running)
        start_with_model "$DEFAULT_MODEL"
        ;;
    *)
        # Pass through any other ollama commands
        exec /bin/ollama "$@"
        ;;
esac