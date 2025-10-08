### Delete Installation Instructions

When you no longer need the Goose environment, you can remove the deployed resources and clean up the Azure Container Apps, Registry, and other associated resources. Run the following commands inside the **goose-on-aca** directory:

```bash
# Delete the container app
az containerapp delete \
  --name <goose-app-name> \
  --resource-group <resource-group-name>

# Delete the resource group (if no other resources are needed)
az group delete \
  --name <resource-group-name> \
  --yes --no-wait

# Delete any Azure Container Registry if no longer required
az acr delete \
  --name <acr-name> \
  --yes
```

> **Tip**
> Replace `<goose-app-name>`, `<resource-group-name>`, and `<acr-name>` with the names you used during deployment.

This will permanently delete all associated Azure resources. If you need to keep any data, ensure you back it up before running these commands.
