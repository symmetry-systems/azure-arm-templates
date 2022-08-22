<#
    .Synopsis
        Configure the diagnostic settings for resource logs of all storage account in all subscriptions to Dataguard storage account.
    .Description
        This script will iterate through all the storage accounts across all subscriptions and configures the dumping of resource logs
        of all the storage accounts found in the dataguard storage account.
#>

param(
    [string]$tenantId, # The Tenant ID where DataGuard is deployed.
    [string]$dataguardSubId, # Dataguard subscription id
    [string]$dataguardResourceGroup, # Dataguard subscription id
    [string]$StorageAccountName # The id of the dataguard storage account.
  )


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

$location_storage_dict = @{}
Set-AzContext -SubscriptionId $dataguardSubId
Get-AzStorageAccount -ResourceGroupName $dataguardResourceGroup | ForEach-Object {
    $found = $_ 
    $location_storage_dict[($_.Location -replace '\s','').ToLower()] = $found.Id
}
Write-Host 'Location vs Storage accounts: ' ($location_storage_dict | Out-String)
  
$DiagnosticSettingName = "dataguard-resouce-diagnostics"

Get-AzSubscription -TenantId $tenantId | Where-Object {$_.HomeTenantId -eq $tenantId} | ForEach-Object {
    if ($_.Id -ne $dataguardSubId) {
        $_ | Set-AzContext
        $currentSubscription = $_                            
        Get-AzStorageAccount | ForEach-Object {
            $storageaccount = $_
            $storageaccountLocation = ($_.Location -replace '\s','').ToLower()
            $targetStorageAccountId = $location_storage_dict[$storageaccountLocation]
            if ($targetStorageAccountId -eq $null) {
                Set-AzContext -SubscriptionId $dataguardSubId
                Get-AzStorageAccount -ResourceGroupName $dataguardResourceGroup | ForEach-Object {
                    $found = $_ 
                    $location_storage_dict[($_.Location -replace '\s','').ToLower()] = $found.Id
                }
                $targetStorageAccountId = $location_storage_dict[$storageaccountLocation]
                if ($targetStorageAccountId -eq $null) {
                    Write-Host 'No target storage account found in region: ' $storageaccountLocation
                    $suffix = $storageaccountLocation -replace '\s',''
                    $suffix = $suffix.subString(0, [System.Math]::Min(7, $suffix.Length))
                    $prefix = $StorageAccountName.subString(0, [System.Math]::Min((24 - $suffix.Length), $StorageAccountName.Length)) 
                    $toCreateName = (-join($prefix, $suffix)).ToLower()
                    $created = New-StorageAccount -ToCreateStorageAccountName $toCreateName -SubscriptionId $dataguardSubId -ResourceGroupName $dataguardResourceGroup -Region $storageaccountLocation
                    $location_storage_dict[($created.Location -replace '\s','').ToLower()] = $created.Id
                    $targetStorageAccountId = $created.Id
                    Write-Host 'Target Storage AccountId: ' $targetStorageAccountId
                    $currentSubscription | Set-AzContext
                }
            }
            $ResourceId = $storageaccount.Id
            Write-Host 'For storage account ' $ResourceId ' in region ' $_.Location ' using dataguard storage account ' $targetStorageAccountId
            $readlog = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category StorageRead -Enabled
            $writelog = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category StorageWrite -Enabled
            $deletelog = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category StorageDelete -Enabled
            $Ids = @($ResourceId + "/blobServices/default"
                    $ResourceId + "/fileServices/default"
                    $ResourceId + "/queueServices/default"
                    $ResourceId + "/tableServices/default"
            )
            $Ids | ForEach-Object {
                $setting = New-AzDiagnosticSetting -Name $DiagnosticSettingName -ResourceId $_ -StorageAccountId $targetStorageAccountId -Setting $readlog,$writelog,$deletelog
                Set-AzDiagnosticSetting -InputObject $setting
            }          
        }
    }       
}