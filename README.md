# goose-on-aca

Deploy Goose AI Agent on Azure Container Apps and run your model on Consumption GPU.

## Overview

This project provides a complete solution for deploying Goose AI Agent as an Azure Container App with GPU support. It includes authentication proxy services and is specifically designed to leverage Azure's pay-as-you-go Consumption billing model for GPU resources.

## Architecture

The deployment consists of two main services:

1. **Goose Agent** - The core AI agent service running in a Docker container
2. **Nginx Auth Proxy** - An authentication proxy that secures access to the Goose Agent

Both services are deployed as Azure Container Apps within a Consumption billing model.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/) installed
- Docker installed for local testing
- An Azure subscription with Container Apps provider enabled

## Installation & Setup

### 1. Clone the repository

```bash
git clone https://github.com/simonjj/goose-on-aca.git
cd goose-on-aca
```

### 2. Create and configure environment variables

Create a `.env` file in the root directory:

```bash
# Required for nginx proxy authentication
export PROXY_AUTH_PASSWORD="your-secure-password-here"

# Optional: Configure other Azure settings
export AZURE_LOCATION="eastus" # or your preferred region
```

### 3. Initialize Azure resources

This will provision the necessary Azure infrastructure using Bicep templates:

```bash
azd up
```

You'll be prompted to login to Azure and select a subscription/region.

During the provisioning process, you may need to set environment variables like `PROXY_AUTH_PASSWORD`.

### 4. Deploy the application

Once infrastructure is provisioned, deploy both services:

```bash
azd deploy --all
```

## Usage

After deployment, your Goose AI Agent will be accessible through the nginx proxy with authentication. The exact URL and access credentials will be provided during the deployment process.

### Local Development

If you want to test locally before deploying to Azure:

```bash
docker-compose up --build
```

## Configuration

### Environment Variables

The main configuration is handled through `azure.yaml` with parameters defined in the Bicep templates. Key variables:

- `PROXY_AUTH_PASSWORD`: Password for basic authentication on the nginx proxy

### Infrastructure Details

- **Provider**: Azure Container Apps with Consumption billing
- **Language**: Bicep infrastructure as code
- **Modules**: Located in `/infra` directory
- **Docker Images**: Multi-stage build supporting CLI and desktop versions of Goose

## Project Structure

```
goose-on-aca/
├── .env                    # Environment variables (not checked into git)
├── azure.yaml              # Azure Developer configuration file
├── Dockerfile              # Multi-stage Dockerfile for Goose agent
├── app/                    # Application source code directories
│   ├── goose/             # Goose agent application
│   └── nginx-auth-proxy/  # Nginx authentication proxy
├── infra/                  # Bicep infrastructure templates
└── hooks/                 # Pipeline hooks (if needed)
```

## Cost Optimization with Consumption GPU

This deployment is designed to leverage Azure's Consumption billing model which offers:
- Pay-as-you-go pricing for GPU compute time
- No minimum commitment required
- Automatic scale-to-zero when idle
- Lower costs compared to reserved capacity

### Monitoring Costs

Monitor your usage in the Azure portal under:
1. Container Apps > Your application
2. Monitor and diagnostics tabs
3. Cost management section

## Troubleshooting

### Common Issues

1. **GPU allocation errors**: Ensure your region has available GPU capacity
2. **Authentication issues**: Verify `PROXY_AUTH_PASSWORD` is set correctly
3. **Docker build failures**: Docker Desktop may need experimental features enabled

### Commands for debugging

```bash
# Check container app logs
azd logs --follow

# Restart services if needed
azd deploy --force-upgrade
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes and test locally
4. Submit a pull request with clear description of changes

## License

This project uses Apache 2.0 license - see [LICENSE](./LICENSE) for details.

## Support

For issues or questions:
1. Check existing GitHub issues first
2. Create new issue with detailed description
3. Include logs and environment information when reporting bugs

## References

- [Azure Container Apps documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Goose AI Agent documentation](https://block.github.io/goose/docs/)
- [Azure Consumption billing](https://learn.microsoft.com/en-us/azure/virtual-machines/preemptible-consumption-billing)