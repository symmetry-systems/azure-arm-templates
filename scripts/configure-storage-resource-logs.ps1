<#
    .Synopsis
        Configure the diagnostic settings for resource logs of all storage account in all subscriptions to Dataguard storage account.
    .Description
        This script will iterate through all the storage accounts across all subscriptions and configures the dumping of resource logs
        of all the storage accounts found in the dataguard storage account.
#>

param(
    [string]$tenantId, # The Tenant ID where DataGuard is deployed.
    [string[]]$subscriptionsList, # The Customer Subscription IDs List.
    [string]$targetStorageAccountId
  )

$DiagnosticSettingName = "dataguard-resouce-diagnostics"

if (-not $subscriptionsList ) {    
    $subscriptionsList = @()
    do {
        $subscription = Read-Host "Enter a Subscription ID (type 'done' when finished) (comma-separated is supported)"
        if ($subscription -ne 'done') {
            $subscriptionsList += $subscription
        }
    } while ($subscription -ne 'done')
}

if (-not $targetStorageAccountId) {
    $targetStorageAccountId = Read-Host "Enter the DataGuard logs storage account"
}    

$subscriptionsList | ConvertFrom-Json |  ForEach-Object {
    
    Set-AzContext -Subscription $_                  
    Get-AzStorageAccount | ForEach-Object {
        $ResourceId =$_.Id
        $log = @()
        $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category StorageRead -RetentionPolicyDay 7 -RetentionPolicyEnabled $true
        $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category StorageWrite -RetentionPolicyDay 7 -RetentionPolicyEnabled $true
        $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category StorageDelete -RetentionPolicyDay 7 -RetentionPolicyEnabled $true
        $Ids = @($ResourceId + "/blobServices/default"
                $ResourceId + "/fileServices/default"
                $ResourceId + "/queueServices/default"
                $ResourceId + "/tableServices/default"
        )
        $Ids | ForEach-Object {
            New-AzDiagnosticSetting -Name $DiagnosticSettingName -ResourceId $_ -StorageAccountId $targetStorageAccountId -Log $log
        }          
    }   
}