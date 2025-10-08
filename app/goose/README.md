# Goose AI Agent Container

This directory contains the containerized setup for the Goose AI agent, configured to run with MCP (Model Context Protocol) servers for enhanced capabilities.


## Building and Testing Locally

This project is intended to ultimately be deployed via `azd up`. Still, this container can be tested locally and standalone. To do so follow these steps:

### Build the Container
```bash
docker build --progress=plain -t goose-cli:local .
```

### Run And Test Against Ollama

```bash
# without github and email mcp servers
docker run --rm -it -p 8099:3000 \
  -v "$PWD"/local:/root/.local \
  -v "$PWD"/config:/root/.config \
  -e OLLAMA_HOST=<YOUR_OLLAMA_HOST> \
  goose-cli:local
  
# with github mcp server enabled
docker run --rm -it -p 8099:3000 \
  -v "$PWD"/local:/root/.local \
  -v "$PWD"/config:/root/.config \
  -e OLLAMA_HOST=<YOUR_OLLAMA_HOST> \
  -e MCP_EMAIL_SERVER_FULL_NAME="Proper Name" \
  -e MCP_EMAIL_SERVER_EMAIL_ADDRESS=<account_email@gmail.com> \
  -e MCP_EMAIL_SERVER_USER_NAME=<account_email@gmail.com> \
  -e MCP_EMAIL_SERVER_PASSWORD='<your access token>' \
  goose-cli:local

# with the email mcp server enabled (currently assuming gmail as provider)
docker run --rm -it -p 8099:3000 \
  -v "$PWD"/local:/root/.local \
  -v "$PWD"/config:/root/.config \
  -e OLLAMA_HOST=<YOUR_OLLAMA_HOST> \
  -e MCP_EMAIL_SERVER_FULL_NAME="Proper Name" \
  -e MCP_EMAIL_SERVER_EMAIL_ADDRESS=<account_email@gmail.com> \
  -e MCP_EMAIL_SERVER_USER_NAME=<account_email@gmail.com> \
  -e MCP_EMAIL_SERVER_PASSWORD='<your access token>' \
  goose-cli:local

# run a interactive CLI agent session
docker run --rm -it \
  -v "$PWD"/local:/root/.local \
  -v "$PWD"/config:/root/.config \
  -e OLLAMA_HOST=<YOUR_OLLAMA_HOST> \
  goose-cli:local session

# run interactive configuration:
docker run --rm -it \
  -v "$PWD"/local:/root/.local \
  -v "$PWD"/config:/root/.config \
  -e OLLAMA_HOST=<YOUR_OLLAMA_HOST> \
  goose-cli:local configure
```
Whenever running `configure` or `session` make sure to volume mount the configuration directory in order to make the agent functional. More extensive edits (such as switching email provider) can be made there or by following the normal Goose config process outlined below.


## Configuration Process Overview

At runtime the config file for Goose can be found under `/root/.config/goose/config.yaml`. Apart from the tools available it also controls the model used.


### Normal Goose Configuration
Typically, Goose is configured interactively using:
```bash
goose configure
```
This creates configuration files in `~/.config/goose/config.yaml`.


### This Image Dynamic Configuration
This project uses a **dynamic configuration** via `handle-default-config.sh`:

1. **Environment Detection**: Script checks for MCP server credentials in environment variables
2. **Change Detection**: Uses SHA256 hashing to detect environment variable changes
3. **Dynamic Generation**: Only regenerates config when environment changes
4. **Selective Activation**: MCP servers are only enabled when their credentials are provided

### Always-Enabled Extensions
- **Computer Controller** (`computercontroller`) - System automation and control
- **Developer Tools** (`developer`) - Development utilities and shell access

### Disabled MCP Servers (Enabled on Demand)
#### Email MCP Server (`zerolib-email`)
- **Status**: Disabled by default
- **Activation**: Set `MCP_EMAIL_SERVER_PASSWORD` (and it's not "NA")
- **Required Environment Variables**:
  - `MCP_EMAIL_SERVER_EMAIL_ADDRESS`
  - `MCP_EMAIL_SERVER_USER_NAME` 
  - `MCP_EMAIL_SERVER_PASSWORD`
  - `MCP_EMAIL_SERVER_FULL_NAME`
- **Configuration**: Pre-configured for Gmail SMTP/IMAP

#### GitHub MCP Server (`github`)
- **Status**: Disabled by default
- **Activation**: Set `GITHUB_PERSONAL_ACCESS_TOKEN` (and it's not "NA")
- **Capabilities**: Repository management, issues, pull requests
- **Toolsets**: `repos,issues,pull_requests`


### Persistence Directories

In the commands above and in the Azure templates these directories are mounted for persistence:

```
Goose Locations:
  Config file:      /root/.config/goose/config.yaml
  Sessions dir:     /root/.local/share/goose/sessions
  Logs dir:         /root/.local/state/goose/logs
```




## Dockerfile Installation Details

The Dockerfile installs:

### Base System
- **Ubuntu 24.04** as the base image
- Essential development tools: `curl`, `git`, `vim`, `nano`, `wget`, `unzip`
- Build tools: `build-essential` for compiling dependencies
- Media tools: `jq`, `tree`, `rsync`, `ffmpeg` for AI agent capabilities
- Minimal X11 libraries for Goose binary compatibility

### Python Environment
- **Python 3** with pip and venv support
- **PEP 668 override** using `--break-system-packages` flag for system-wide package installation
- **pandas** and other data analysis libraries from `requirements.txt`

### Goose CLI
- **Goose CLI** installed from official release (stable version)
- **GitHub MCP server** binary (v0.17.1) for GitHub integration
- Web UI accessible on port 3000 by default

### Removed Components
- **Playwright** dependencies removed for container optimization (reduces size significantly)
- **Multi-stage build** simplified to single-stage for faster builds