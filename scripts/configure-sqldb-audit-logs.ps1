<#
    .Synopsis
        Allow Dataguard VNet access to all SQL DBs through Service Endpoints.
    .Description
        
#>
param(
  [string]$tenantId, # The Tenant ID where DataGuard is deployed.
  [string]$dataguardSubId, # Dataguard subscription id
  [string]$StorageAccountId,  # The id of the dataguard storage account.
  [string]$Region
)

# $disabled = @() 
# $Result=@()
# $tenantId = '938e7f1c-a9cc-47d3-897f-a12d33bf6c38'
# $dataguardSubId = 'b3f51724-9bff-43e5-9a6a-23f236ff683d'
# $subnetId = '/subscriptions/b3f51724-9bff-43e5-9a6a-23f236ff683d/resourceGroups/DataGuard_Demo_3_Grp/providers/Microsoft.Network/virtualNetworks/dataguard-vnet/subnets/app-gw-subnet'
# $StorageAccountId = '/subscriptions/b3f51724-9bff-43e5-9a6a-23f236ff683d/resourceGroups/azure-test-rg/providers/Microsoft.Storage/storageAccounts/dgwestplaintest'

Set-AzContext -SubscriptionId $dataguardSubId
Register-AzResourceProvider -ProviderNamespace Microsoft.Sql

Get-AzSubscription -TenantId $tenantId | Where-Object {$_.HomeTenantId -eq $tenantId} | ForEach-Object {
        $_ | Set-AzContext
        Get-AzResourceGroup | ForEach-Object {
            $resourceGroupName = $_.ResourceGroupName
            
            Get-AzSqlServer -ResourceGroupName $resourceGroupName | Where-Object {(($_.Location -eq $Region) -or ($Region -eq $null))} | ForEach-Object {
                Set-AzSqlServerAudit -ResourceGroupName $resourceGroupName `
                    -ServerName  $_.ServerName `
                    -BlobStorageTargetState Enabled `
                    -StorageAccountResourceId $StorageAccountId
            }
        }                            
        
    }
