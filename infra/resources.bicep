targetScope = 'resourceGroup'

@description('The location of this resource group')
param location string

@description('Environment name used for deriving resource names')
param environmentName string

@description('A suffix to provide resource naming uniqueness')
param resourceToken string

var baseName = toLower('${environmentName}-${resourceToken}')
var sanitized = toLower(replace(replace(environmentName, '-', ''), '_', ''))
var sanitizedBase = empty(sanitized) ? 'env' : sanitized
var containerRegistryName = take('acr${sanitizedBase}${resourceToken}00', 50)
var storageAccountName = take('st${sanitizedBase}${resourceToken}000', 24)
var identityName = 'id-${baseName}'
var containerAppsEnvironmentName = 'cae-${baseName}'
var ollamaAppName = 'ollama-${baseName}'
var gooseAppName = 'goose-${baseName}'
var seedScript = format('az account set --subscription {0}\nsleep 60\naz acr import --resource-group {1} --name {2} --source mcr.microsoft.com/azuredocs/containerapps-helloworld:latest --image goose-agent:latest\naz acr import --resource-group {1} --name {2} --source mcr.microsoft.com/azuredocs/containerapps-helloworld:latest --image ollama:latest', subscription().subscriptionId, resourceGroup().name, containerRegistryName)

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: 'vnet-${baseName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aca-subnet'
        properties: {
          addressPrefix: '10.0.0.0/23'
          delegations: [
            {
              name: 'aca-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'pe-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    zoneRedundancy: 'Disabled'
  }
}
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

resource seedImages 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'seed-acr-images'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.61.0'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    scriptContent: seedScript
  }
  dependsOn: [
    containerRegistry
    acrPushAssignment
    acrReaderAssignment
    acrContributorAssignment
  ]
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: false
    allowSharedKeyAccess: true
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource gooseLocalShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'goose-local'
  properties: {
    enabledProtocols: 'NFS'
    shareQuota: 256
    rootSquash: 'NoRootSquash'
  }
}

resource gooseConfigShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'goose-config'
  properties: {
    enabledProtocols: 'NFS'
    shareQuota: 128
    rootSquash: 'NoRootSquash'
  }
}

resource ollamaModelShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'ollama-model'
  properties: {
    enabledProtocols: 'NFS'
    shareQuota: 1024
    rootSquash: 'NoRootSquash'
  }
}

resource storagePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
}

resource storagePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storagePrivateDnsZone
  name: '${virtualNetwork.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = {
  name: '${storageAccount.name}-pe'
  location: location
  properties: {
    subnet: {
      id: '${virtualNetwork.id}/subnets/pe-subnet'
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

resource storagePrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = {
  parent: storagePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'file'
        properties: {
          privateDnsZoneId: storagePrivateDnsZone.id
        }
      }
    ]
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvironmentName
  location: location
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: '${virtualNetwork.id}/subnets/aca-subnet'
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: 'GPU'
        workloadProfileType: 'Consumption-GPU-NC8as-T4'
      }
    ]
  }
}

resource gooseLocalStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerAppsEnvironment
  name: 'goose-local-storage'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: gooseLocalShare.name
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
      shareName: gooseConfigShare.name
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
      shareName: ollamaModelShare.name
      accessMode: 'ReadWrite'
      accountKey: storageAccount.listKeys().keys[0].value
    }
  }
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, userAssignedIdentity.name, 'AcrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrPushAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, userAssignedIdentity.name, 'AcrPush')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrReaderAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, userAssignedIdentity.name, 'Reader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrContributorAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, userAssignedIdentity.name, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource ollamaApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: ollamaAppName
  location: location
  tags: {'azd-service-name': 'ollama'}
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  dependsOn: [
    seedImages
  ]
  properties: {
    environmentId: containerAppsEnvironment.id
    workloadProfileName: 'GPU'
    configuration: {
      ingress: {
        external: false
        targetPort: 11434
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: userAssignedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ollama'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          env: [
            {
              name: 'OLLAMA_CONTEXT_LENGTH'
              value: '32768'
            }
            {
              name: 'OLLAMA_HOST'
              value: '0.0.0.0:11434'
            }
          ]
          resources: {
            cpu: 4
            memory: '16Gi'
          }
          volumeMounts: [
            {
              volumeName: 'ollama-models'
              mountPath: '/root/.ollama'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'ollama-models'
          storageType: 'AzureFile'
          storageName: ollamaModelStorage.name
        }
      ]
    }
  }
}

resource gooseApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: gooseAppName
  location: location
  tags: {'azd-service-name': 'goose-agent'}
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  dependsOn: [
    seedImages
  ]
  properties: {
    environmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: userAssignedIdentity.id
        }
      ]
      secrets: []
    }
    template: {
      containers: [
        {
          name: 'goose'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          env: [
            {
              name: 'OLLAMA_HOST'
              value: 'https://${ollamaApp.properties.configuration.ingress.fqdn}'
            }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          volumeMounts: [
            {
              volumeName: 'goose-local'
              mountPath: '/root/.local'
            }
            {
              volumeName: 'goose-config'
              mountPath: '/root/.config'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'goose-local'
          storageType: 'AzureFile'
          storageName: gooseLocalStorage.name
        }
        {
          name: 'goose-config'
          storageType: 'AzureFile'
          storageName: gooseConfigStorage.name
        }
      ]
    }
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnvironment.id
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = containerAppsEnvironment.name
output ACA_ENVIRONMENT_IDENTITY_ID string = userAssignedIdentity.id
output GOOSE_APP_NAME string = gooseApp.name
output OLLAMA_APP_NAME string = ollamaApp.name