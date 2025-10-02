targetScope = 'resourceGroup'

@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@description('Primary location for all resources')
param location string

@description('Password for nginx auth proxy basic authentication')
@secure()
param proxyAuthPassword string

@description('Toggle diagnostic logging through a Log Analytics workspace')
param enableDebugging bool = false

// Variables
var resourceToken = take(toLower(uniqueString(subscription().id, environmentName, location)), 5)


// Main infrastructure
module resources 'resources.bicep' = {
  name: 'resources'
  params: {
    location: location
    environmentName: environmentName
    resourceToken: resourceToken
    proxyAuthPassword: proxyAuthPassword
    enableDebugging: enableDebugging
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_CONTAINER_REGISTRY_NAME string = resources.outputs.AZURE_CONTAINER_REGISTRY_NAME
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME
output AZURE_CONTAINERAPPS_SERVICE_GOOSE_AGENT_NAME string = resources.outputs.GOOSE_APP_NAME
output AZURE_CONTAINERAPPS_SERVICE_OLLAMA_NAME string = resources.outputs.OLLAMA_APP_NAME
output AZURE_CONTAINERAPPS_SERVICE_NGINX_AUTH_PROXY_NAME string = resources.outputs.NGINX_AUTH_PROXY_APP_NAME
output LOG_ANALYTICS_WORKSPACE_ID string = resources.outputs.LOG_ANALYTICS_WORKSPACE_ID