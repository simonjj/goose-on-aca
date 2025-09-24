targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters
@description('Tags to apply to all resources')
param tags object = {}

@description('Enable Application Insights for monitoring')
param enableApplicationInsights bool = true

@description('Enable Log Analytics workspace')
param enableLogAnalytics bool = true

// Variables
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Main infrastructure module
module resources './app/resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
    tags: tags
    environmentName: environmentName
    resourceToken: resourceToken
    enableApplicationInsights: enableApplicationInsights
    enableLogAnalytics: enableLogAnalytics
  }
}

// Container Apps module
module containerApps './app/container-apps.bicep' = {
  name: 'container-apps'
  scope: rg
  params: {
    location: location
    tags: tags
    environmentName: environmentName
    containerAppsEnvironmentId: resources.outputs.containerAppsEnvironmentId
    containerRegistryName: resources.outputs.containerRegistryName
    logAnalyticsWorkspaceName: resources.outputs.logAnalyticsWorkspaceName
    applicationInsightsConnectionString: resources.outputs.applicationInsightsConnectionString
    storageAccountName: resources.outputs.storageAccountName
  }
}

// Outputs
@description('The name of the resource group')
output AZURE_RESOURCE_GROUP_NAME string = rg.name

@description('The name of the container registry')
output AZURE_CONTAINER_REGISTRY_NAME string = resources.outputs.containerRegistryName

@description('The name of the container apps environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = resources.outputs.containerAppsEnvironmentName

@description('The name of the log analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = resources.outputs.logAnalyticsWorkspaceName

@description('The connection string for Application Insights')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = resources.outputs.applicationInsightsConnectionString