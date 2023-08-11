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
    [string]$targetStorageAccountId # Target DataGuard logs storage account resource ID.
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

if (-not $targetStorageAccountId) {
    $targetStorageAccountId = Read-Host "Enter the target DataGuard logs storage account resource ID"
}

if (-not $action) {
    $action = Read-Host "Enter the script action ('create' or 'remove')"
}

if ($action -notin @('create', 'remove')) {
    Write-Host "Invalid action specified. Please enter either 'create' or 'remove'." -ForegroundColor Red
    exit 1
}

function Configure {
    param (
        [bool]$enabled
    )
    $action = $enabled ? "enabled" : "disabled"
    Write-Host "Configuring storage resource logs..." 
        Get-AzStorageAccount | ForEach-Object {
            $ResourceId =$_.Id
            $log = @()
            $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $enabled -Category StorageRead -RetentionPolicyDay 7 -RetentionPolicyEnabled $true
            $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $enabled -Category StorageWrite -RetentionPolicyDay 7 -RetentionPolicyEnabled $true
            $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $enabled  -Category StorageDelete -RetentionPolicyDay 7 -RetentionPolicyEnabled $true
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
elseif ($subscriptionsList -ne $null) {
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