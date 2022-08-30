<#
    .Synopsis
        Allow Dataguard VNet access to all cosmos DBs through Service Endpoints.
    .Description
        
#>
param(
  [string]$tenantId, # The Tenant ID where DataGuard is deployed.
  [string]$subnetId, # The name of the subnet in which to create service endpoint.
  [string]$dataguardSubId, # Dataguard subscription id
  [string]$dataguardResourceGroup, # Dataguard subscription id
  [string]$StorageAccountName, # The id of the dataguard storage account.
  [string]$DataguardIdentity # The principal id of the dataguard managed identioty.
)

$disabled = @() 
$Result=@()
# $tenantId = '938e7f1c-a9cc-47d3-897f-a12d33bf6c38'
# $dataguardSubId = 'b3f51724-9bff-43e5-9a6a-23f236ff683d'
# $subnetId = '/subscriptions/b3f51724-9bff-43e5-9a6a-23f236ff683d/resourceGroups/DataGuard_Demo_3_Grp/providers/Microsoft.Network/virtualNetworks/dataguard-vnet/subnets/private-subnet'
# $DataguardIdentity = "bedc2f53-8a62-4e42-9960-b07c72ae4c46"
# $StorageAccountName = 'storeb7paby5iarm6a'

function New-StorageAccount {

    param (
        [string]$ToCreateStorageAccountName,
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [string]$Region
    )
    Process {
        Set-AzContext -SubscriptionId $SubscriptionId

        New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
            -Name $ToCreateStorageAccountName `
            -Location $Region `
            -SkuName Standard_GRS `
            -Kind BlobStorage `
            -AccessTier Hot `
            -EnableHierarchicalNamespace $false
        $created = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $ToCreateStorageAccountName
        Write-Host 'Created a new storage account in region ' $Region ' by name ' $ToCreateStorageAccountName
        return $created

    }
}

Set-AzContext -SubscriptionId $dataguardSubId
Register-AzResourceProvider -ProviderNamespace Microsoft.DocumentDB

$location_storage_dict = @{}
Get-AzStorageAccount -ResourceGroupName $dataguardResourceGroup | ForEach-Object {
    $found = $_ 
    $location_storage_dict[($_.Location -replace '\s','').ToLower()] = $found.Id
}
Write-Host 'Location vs Storage accounts: ' ($location_storage_dict | Out-String)

Get-AzSubscription -TenantId $tenantId | Where-Object {$_.HomeTenantId -eq $tenantId} | ForEach-Object {
        $_ | Set-AzContext
        $currentSubscription = $_
        
        Get-AzResourceGroup | ForEach-Object {
            $resourceGroupName = $_.ResourceGroupName
            
            Get-AzCosmosDBAccount -ResourceGroupName $resourceGroupName | ForEach-Object {
                $accountName = $_.Name
                $accountKind = $_.Kind
                $cosmosAccountLocation = ($_.Location -replace '\s','').ToLower()
                if ($accountKind -eq 'GlobalDocumentDB') {
                    $roleName = 'DataguardCosmosReadOnly'
                    $readOnlyRoleDefinition = Get-AzCosmosDBSqlRoleDefinition -AccountName $accountName `
                        -ResourceGroupName $resourceGroupName | Where-Object {$_.RoleName -eq $roleName} 
                    if ($readOnlyRoleDefinition -eq $null) {
                        New-AzCosmosDBSqlRoleDefinition -AccountName $accountName `
                        -ResourceGroupName $resourceGroupName `
                        -Type CustomRole -RoleName $roleName `
                        -DataAction @( `
                            'Microsoft.DocumentDB/databaseAccounts/readMetadata',
                            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read', `
                            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery', `
                            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed') `
                        -AssignableScope "/"
                    }
                        
                    $readOnlyRoleDefinition = Get-AzCosmosDBSqlRoleDefinition -AccountName $accountName `
                        -ResourceGroupName $resourceGroupName | Where-Object {$_.RoleName -eq $roleName} 
                    $readOnlyRoleDefinitionId = $readOnlyRoleDefinition.Id
                    Write-Host $readOnlyRoleDefinitionId
                    New-AzCosmosDBSqlRoleAssignment -AccountName $accountName `
                        -ResourceGroupName $resourceGroupName `
                        -RoleDefinitionId $readOnlyRoleDefinitionId `
                        -Scope "/" `
                        -PrincipalId $DataguardIdentity
                }
                $ResourceId = $_.Id
                $targetStorageAccountId = $location_storage_dict[$cosmosAccountLocation]
                if ($targetStorageAccountId -eq $null) {
                    Set-AzContext -SubscriptionId $dataguardSubId
                    Get-AzStorageAccount -ResourceGroupName $dataguardResourceGroup | ForEach-Object {
                        $found = $_ 
                        $location_storage_dict[($_.Location -replace '\s','').ToLower()] = $found.Id
                    }
                    $targetStorageAccountId = $location_storage_dict[$cosmosAccountLocation]
                    if ($targetStorageAccountId -eq $null) {
                        Write-Host 'No target storage account found in region: ' $cosmosAccountLocation
                        $suffix = $cosmosAccountLocation -replace '\s',''
                        $prefix = $StorageAccountName.subString(0, [System.Math]::Min((24 - $suffix.Length), $StorageAccountName.Length)) 
                        $toCreateName = (-join($prefix, $suffix)).ToLower()
                        $created = New-StorageAccount -ToCreateStorageAccountName $toCreateName -SubscriptionId $dataguardSubId -ResourceGroupName $dataguardResourceGroup -Region $cosmosAccountLocation
                        $location_storage_dict[($created.Location -replace '\s','').ToLower()] = $created.Id
                        $targetStorageAccountId = $created.Id
                        $currentSubscription | Set-AzContext
                    }
                }

                $dataPlaneReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category DataPlaneRequests -Enabled
                $controlPlaneReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category ControlPlaneRequests -Enabled
                $mongoReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category MongoRequests -Enabled
                $cassandraReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category CassandraRequests -Enabled
                $gremlinReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category GremlinRequests -Enabled
                $tableApiReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category TableApiRequests -Enabled
                $DiagnosticSettingName = "dataguard-resouce-diagnostics"
                $setting = New-AzDiagnosticSetting `
                    -Name $DiagnosticSettingName `
                    -ResourceId $ResourceId `
                    -StorageAccountId $targetStorageAccountId `
                    -Setting $dataPlaneReqs,$controlPlaneReqs,$mongoReqs,$cassandraReqs,$gremlinReqs,$tableApiReqs
                Set-AzDiagnosticSetting -InputObject $setting
                
                $Result += New-Object PSObject -property @{ 
                    Id = $_.Id
                    Name = $accountName
                    ResourceGroup = $resourceGroupName
                    IpRangeFilter = $_.IpRangeFilter
                    VirtualNetworkRules = $_.VirtualNetworkRules
                    NetworkAclBypass = $_.NetworkAclBypass
                    NetworkAclBypassResourceIds = $_.NetworkAclBypassResourceIds
                    PublicNetworkAccess = $_.PublicNetworkAccess
                    IsVirtualNetworkFilterEnabled = $_.IsVirtualNetworkFilterEnabled
                }

                if ( ($_.PublicNetworkAccess -eq 'Enabled') -and ($_.IsVirtualNetworkFilterEnabled -eq $true -or $_.IpRules.Count -ge 0)){
                    Write-Host 'Adding service endpoint to ' $subnetId
                    $vnetRule = New-AzCosmosDBVirtualNetworkRule -Id $subnetId
                    Update-AzCosmosDBAccount -ResourceGroupName $resourceGroupName `
                        -Name $accountName `
                        -EnableVirtualNetwork $true `
                        -VirtualNetworkRuleObject @($vnetRule)
                } else {
                    Write-Host 'NOT Adding service endpoint because $_.PublicNetworkAccess ' $_.PublicNetworkAccess ' and $_.IsVirtualNetworkFilterEnabled ' $_.IsVirtualNetworkFilterEnabled 
                }
                if ($_.PublicNetworkAccess -eq 'Disabled') {
                    $disabled += $_
                }
            }
        }                            
        
    }

-join('["', (($disabled).Id -join '","'), '"]') | Out-File "~/disabled_cosmosdb_accounts.txt"