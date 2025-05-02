param location string = resourceGroup().location
param vnetName string = 'ent-vnet'
param addressPrefix string = '10.0.0.0/16'

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'app-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgApp.id
          }
        }
      }
      {
        name: 'db-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: nsgDb.id
          }
        }
      }
    ]
  }
}

// NSG for app-subnet
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
    name: 'nsg-app-subnet'
    location: location
    properties: {
      securityRules: [
        {
          name: 'Allow-HTTP'
          properties: {
            priority: 100
            direction: 'Inbound'
            access: 'Allow'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '80'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
          }
        }
      ]
    }
  }
  
  // NSG for db-subnet
  resource nsgDb 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
    name: 'nsg-db-subnet'
    location: location
    properties: {
      securityRules: [
        {
          name: 'Deny-All-Inbound'
          properties: {
            priority: 200
            direction: 'Inbound'
            access: 'Deny'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
          }
        }
      ]
    }
  }
  

  // Public IP for the firewall
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: 'fw-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Azure Firewall
resource azureFirewall 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: 'ent-fw'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'azureFirewallIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AzureFirewallSubnet')
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'net-rule-collection'
        properties: {
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'Allow-DNS'
                sourceAddresses: ['10.0.1.0/24']
                destinationAddresses: ['8.8.8.8']
                destinationPorts: ['53']
                protocols: ['UDP']

            }
          ]
        }
      }
    ]
    applicationRuleCollections: [
      {
        name: 'app-rule-collection'
        properties: {
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'Allow-GitHub'
                sourceAddresses: ['10.0.1.0/24']
                protocols: [
                  {
                    protocolType: 'Https'
                    port: 443
                  }
                ]
                targetFqdns: ['*.github.com']
              
            }
          ]
        }
      }
    ]
  }
}

