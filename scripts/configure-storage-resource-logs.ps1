<#
    .Synopsis
        Configure the diagnostic settings for resource logs of all storage account in tenant or selected subscriptions to Dataguard storage account.
    .Description
        This script will iterate through all the storage accounts across all specified subscriptions and configures the dumping of storage resource logs
        in the dataguard storage account.
#>

param(
    [string]$tenantId, # The Tenant ID where DataGuard is deployed.
    [string[]]$subscriptionsList, # The Customer Subscription IDs List.
    [string]$dataguardResourceGroupID # Target DataGuard resource group ID with target logs storage accounts.
  )

$DiagnosticSettingName = "dataguard-resouce-diagnostics"

if (-not $tenantId -and -not $subscriptionsList ) {
    $inputOption = Read-Host "Choose an input option:`n1. Apply for all Subscriptions in Tenant.`n2. Apply for selected Subsriptions.`nOption"
    
    if ($inputOption -eq "1") {
        $tenantId = Read-Host "Enter the Customer Tenant ID"
    } 
    elseif ($inputOption -eq "2") {
        $subscriptionsList = @()
        do {
            $subscription = Read-Host "Enter a Subscription ID (type 'done' when finished) (comma-separated is supported)"
            if ($subscription -ne 'done') {
                $subscriptionsList += $subscription
            }
        } while ($subscription -ne 'done')
    }
}

if (-not $dataguardResourceGroupID) {
    $dataguardResourceGroupID = Read-Host "Enter the resource group ID that contain target storage accounts"
}

if (-not $action) {
    $action = Read-Host "Enter the script action ('create' or 'remove')"
}

if ($action -notin @('create', 'remove')) {
    Write-Host "Invalid action specified. Please enter either 'create' or 'remove'." -ForegroundColor Red
    exit 1
}

if ($dataguardResourceGroupID -match "/subscriptions/([0-9a-fA-F-]+)/resourceGroups/([^/]+)") {
    $dataguardSubId = $matches[1]
    $dataguardResourceGroupName = $matches[2]
}

$location_storage_dict = @{}
Set-AzContext -SubscriptionId $dataguardSubId
Get-AzStorageAccount -ResourceGroupName $dataguardResourceGroupName | ForEach-Object {
    $location_storage_dict[($_.Location -replace '\s','').ToLower()] = $_.Id
}
function Configure {
    param (
        [bool]$enabled
    )
    $action = $enabled ? "enabled" : "disabled"
    Write-Host "Configuring storage resource logs..." 
        Get-AzStorageAccount | ForEach-Object {
            $ResourceId =$_.Id            
            $storageaccountLocation = ($_.Location -replace '\s','').ToLower()
            $targetStorageAccountId = $location_storage_dict[$storageaccountLocation]

            if ($null -eq $targetStorageAccountId) {
                $result = 'No target storage account found in region ' + $storageaccountLocation + ' for storage account ' + $_.StorageAccountName
                Write-Host $result
                $result | Out-File -Append "~/storage_resource_log_output.txt"
                return
            }

            $log = @()
            $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $enabled -Category StorageRead
            $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $enabled -Category StorageWrite
            $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $enabled  -Category StorageDelete
            $Ids = @($ResourceId + "/blobServices/default"
                    $ResourceId + "/fileServices/default"
                    $ResourceId + "/queueServices/default"
                    $ResourceId + "/tableServices/default"
            )
            $Ids | ForEach-Object {
                New-AzDiagnosticSetting -Name $DiagnosticSettingName -ResourceId $_ -StorageAccountId $targetStorageAccountId -Log $log
                $result = $? ? "DataGuard resource log $action for: " + $_  : "Something went wrong trying to $action DataGuard resource log for: " + $_
                Write-Host $result
                $result | Out-File -Append "~/storage_resource_log_output.txt"
            }          
    }
}

if ($tenantId -ne ""){
    Get-AzSubscription -TenantId $tenantId | Where-Object {$_.HomeTenantId -eq $tenantId} | ForEach-Object {
        Set-AzContext -Subscription $_
        if ($action -eq "create"){
            Configure -enabled $true
        }
        else {
            Configure -enabled $false
        }
    }
}
elseif ($null -ne $subscriptionsList) {
    $subscriptionsArray = $subscriptionsList -split ','
    $subscriptionsArray | ForEach-Object {
        Set-AzContext -Subscription $_
        if ($action -eq "create"){
            Configure -enabled $true
        }
        else {
            Configure -enabled $false
        }
    }          
}
