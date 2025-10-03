// Parameters for dependencies
param location string = resourceGroup().location

param environmentName string
param containerAppsEnvironmentId string

param userAssignedIdentityId string
param containerRegistryEndpoint string

param ollamaAppName string
param ollamaModelStorageName string


resource ollamaApp 'Microsoft.App/containerApps@2025-02-02-preview' = {
  name: ollamaAppName
  location: location
  tags: {'azd-env-name': environmentName, 'azd-service-name': 'ollama'}
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironmentId
    workloadProfileName: 'GPU'
    configuration: {
      ingress: {
        external: false
        targetPort: 11434
        allowInsecure: true
      }
      registries: [
        {
          server: containerRegistryEndpoint
          identity: userAssignedIdentityId
        }
      ]
    }
    template: {
      initContainers: [
        {
          name: 'ollama-prefetch'
          // we use a prebuild container that pulls the models we need
          image: 'ghcr.io/simonjj/ollama-model-pull:3102025-1240'
          resources: {
            cpu: 2
            memory: '4Gi'
          }
          volumeMounts: [
            {
              volumeName: 'ollama-models'
              mountPath: '/root/.ollama'
            }
          ]
        }
      ]
      containers: [
        {
          name: 'ollama'
          image: 'docker.io/ollama/ollama'
          env: [
            {
              name: 'OLLAMA_CONTEXT_LENGTH'
              value: '32768'
            }
            {
                name: 'OLLAMA_KEEP_ALIVE'
                value: '15m'
            }
          ]
          resources: {
            cpu: 8
            memory: '56Gi'
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
          storageType: 'NfsAzureFile'
          storageName: ollamaModelStorageName
        }
      ]
    }
  }
}


output OLLAMA_HOST string = ollamaApp.properties.configuration.ingress.fqdn