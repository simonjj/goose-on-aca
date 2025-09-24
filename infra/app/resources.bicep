param location string
param tags object = {}
param environmentName string
param resourceToken string
param enableApplicationInsights bool = true
param enableLogAnalytics bool = true

// Load abbreviations
var abbrs = loadJsonContent('../abbreviations.json')

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (enableLogAnalytics) {
  name: '${abbrs.operationalInsightsWorkspaces}${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if (enableApplicationInsights) {
  name: '${abbrs.insightsComponents}${environmentName}-${resourceToken}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: enableLogAnalytics ? logAnalyticsWorkspace.id : null
  }
}

// Container Registry
// Name must be 5-50 chars, alphanumeric only
var containerRegistryName = '${abbrs.containerRegistryRegistries}${toLower(replace(replace(environmentName, '-', ''), '_', ''))}${resourceToken}'
var cleanContainerRegistryName = take(containerRegistryName, 50)

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: cleanContainerRegistryName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Storage Account for file shares
// Name must be 3-24 chars, lowercase letters and numbers only
var storageAccountName = '${abbrs.storageStorageAccounts}${toLower(replace(replace(environmentName, '-', ''), '_', ''))}${resourceToken}'
var cleanStorageAccountName = take(storageAccountName, 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: cleanStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: '${abbrs.networkVirtualNetworks}${environmentName}-${resourceToken}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'container-apps-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'containerAppsEnvironments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'private-endpoints-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Private DNS Zone for Storage Account
resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to VNet
resource storageDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${virtualNetwork.name}-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
    registrationEnabled: false
  }
}

// Private Endpoint for Storage Account
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = {
  name: '${storageAccount.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '${virtualNetwork.id}/subnets/private-endpoints-subnet'
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccount.name}-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

// DNS Zone Group for Storage Private Endpoint
resource storagePrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = {
  parent: storagePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-file-core-windows-net'
        properties: {
          privateDnsZoneId: storageDnsZone.id
        }
      }
    ]
  }
}

// File Shares
resource gooseLocalShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/goose-local'
  properties: {
    enabledProtocols: 'SMB'
  }
}

resource gooseConfigShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/goose-config'
  properties: {
    enabledProtocols: 'SMB'
  }
}

resource ollamaModelShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/ollama-model'
  properties: {
    enabledProtocols: 'SMB'
  }
}

// Container Apps Environment with custom VNet and managed identity
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${abbrs.appManagedEnvironments}${environmentName}-${resourceToken}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: enableLogAnalytics ? logAnalyticsWorkspace.properties.customerId : ''
        sharedKey: enableLogAnalytics ? logAnalyticsWorkspace.listKeys().primarySharedKey : ''
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: '${virtualNetwork.id}/subnets/container-apps-subnet'
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: 'GPU-T4'
        workloadProfileType: 'D4'
        minimumCount: 0
        maximumCount: 10
      }
    ]
  }
}

// Storage definitions for Container Apps
resource gooseLocalStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerAppsEnvironment
  name: 'goose-local-storage'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: 'goose-local'
      accessMode: 'ReadWrite'
      accountKey: storageAccount.listKeys().keys[0].value
    }
  }
}

resource gooseConfigStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerAppsEnvironment
  name: 'goose-config-storage'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: 'goose-config'
      accessMode: 'ReadWrite'
      accountKey: storageAccount.listKeys().keys[0].value
    }
  }
}

resource ollamaModelStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerAppsEnvironment
  name: 'ollama-model-storage'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: 'ollama-model'
      accessMode: 'ReadWrite'
      accountKey: storageAccount.listKeys().keys[0].value
    }
  }
}

// Role assignments for Container Registry
resource containerRegistryPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role
}

resource containerRegistryPushRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush role
}

// Note: Role assignments for managed identities will be handled post-deployment
// since we need the runtime identity principal IDs

// Outputs
output containerRegistryName string = containerRegistry.name
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output logAnalyticsWorkspaceName string = enableLogAnalytics ? logAnalyticsWorkspace.name : ''
output applicationInsightsConnectionString string = enableApplicationInsights ? applicationInsights.properties.ConnectionString : ''
output storageAccountName string = storageAccount.name
output virtualNetworkId string = virtualNetwork.id