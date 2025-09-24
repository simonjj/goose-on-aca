param location string
param tags object = {}
param environmentName string
param containerAppsEnvironmentId string
param containerRegistryName string
param logAnalyticsWorkspaceName string
param applicationInsightsConnectionString string
param storageAccountName string

// Load abbreviations
var abbrs = loadJsonContent('../abbreviations.json')

// Get existing resources
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

// Role definitions for Container Registry access
resource containerRegistryPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role
}

// Ollama Container App
resource ollamaApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${abbrs.appContainerApps}ollama-${environmentName}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: containerAppsEnvironmentId
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 11434
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ollama'
          image: '${containerRegistry.properties.loginServer}/ollama:latest'
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
            memory: '8Gi'
          }
          volumeMounts: [
            {
              mountPath: '/root/.ollama'
              volumeName: 'ollama-models'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
      volumes: [
        {
          name: 'ollama-models'
          storageType: 'AzureFile'
          storageName: 'ollama-model-storage'
        }
      ]
    }
  }
}

// Goose Agent Container App
resource gooseApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${abbrs.appContainerApps}goose-${environmentName}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: containerAppsEnvironmentId
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'applicationinsights-connection-string'
          value: applicationInsightsConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'goose'
          image: '${containerRegistry.properties.loginServer}/goose-agent:latest'
          env: [
            {
              name: 'OLLAMA_HOST'
              value: '${ollamaApp.properties.configuration.ingress.fqdn}:80'
            }
            {
              name: 'GOOSE_MODEL'
              value: 'qwen3:14b'
            }
            {
              name: 'GOOSE_PROVIDER'
              value: 'ollama'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'applicationinsights-connection-string'
            }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          volumeMounts: [
            {
              mountPath: '/root/.local'
              volumeName: 'goose-local'
            }
            {
              mountPath: '/root/.config'
              volumeName: 'goose-config'
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
          storageName: 'goose-local-storage'
        }
        {
          name: 'goose-config'
          storageType: 'AzureFile'
          storageName: 'goose-config-storage'
        }
      ]
    }
  }
}

// Note: Role assignments for ACR access are handled post-deployment
// since managed identity principal IDs are only available at runtime

// Outputs
output ollamaAppName string = ollamaApp.name
output ollamaAppFqdn string = ollamaApp.properties.configuration.ingress.fqdn
output gooseAppName string = gooseApp.name