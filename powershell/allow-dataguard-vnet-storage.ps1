<#
    .Synopsis
        Allow Dataguard VNet access to all storage accounts through Service Endpoints.
    .Description
        This script will iterate through all the storage accounts across a specified subscription.
        If it found storage account :
        * that allows access from all networks - then it will do nothing
        * that allows access from selected networks - then it will ADD dataguard VNet to the allowed network list
        * that blocks all networks - then it will not modify anything but just report the disabled storage account for further review.
        
        NOTE: This script only allows Dataguard network to be allowed for storage account. As such it does not give any permission.
        Permissions still continue to be governed by the Role Assignments.
#>
param(
  [string]$tenantId, # The Customer Tenant
  [string[]]$subscriptionsList, # The Customer Subscription IDs List.
  [string]$subnetId, # The  private subnet resource ID.
  [string]$action # Specify either to 'create' or 'remove' the defined network configuration rule.
)

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

if (-not $subnetId) {
    $subnetId = Read-Host "Enter the DataGuard private subnet resource ID"
}

if (-not $action) {
    $action = Read-Host "Enter the script action ('create' or 'remove')"
}

if ($action -notin @('create', 'remove')) {
    Write-Host "Invalid action specified. Please enter either 'create' or 'remove'." -ForegroundColor Red
    exit 1
}

function Create {
    Write-Host "Adding network rule..."
    Get-AzStorageAccount | ForEach-Object {
        $storageAccount = $_
        if ($_.PublicNetworkAccess -eq 'Disabled') {
            Write-Host "Public network access disabled for: " $_.StorageAccountName
            -join('["', (($_).Id -join '","'), '"]') | Out-File "~/disabled_storage_accounts.txt"
            return
        }
        Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $_.ResourceGroupName -AccountName $_.StorageAccountName | ForEach-Object {
            if ( $_.DefaultAction -eq 'Deny' ){
                Add-AzStorageAccountNetworkRule -ResourceGroupName $storageAccount.ResourceGroupName -AccountName $storageAccount.StorageAccountName -VirtualNetworkRule (
                    @{VirtualNetworkResourceId = $subnetId}
                )
                $result = $? ? "DataGuard network configuration added for: " + $storageAccount.StorageAccountName  : "Something went wrong trying to add network configuration for: " + $storageAccount.StorageAccountName
                Write-Host $result
            }
        }           
    }
}

function Remove {
    Write-Host "Removing network rule..."
    Get-AzStorageAccount | ForEach-Object {
        $storageAccount = $_
        if ($_.PublicNetworkAccess -eq 'Disabled') {
            Write-Host "Public network access disabled for: " $_.StorageAccountName
            return
        }
        Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $_.ResourceGroupName -AccountName $_.StorageAccountName | ForEach-Object {
                if ($_.virtualNetworkRules.VirtualNetworkResourceId -eq $subnetId ){
                    Write-Host "DataGuard network configuration found for: " $storageAccount.StorageAccountName
                    Remove-AzStorageAccountNetworkRule -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName -VirtualNetworkRule (
                        @{VirtualNetworkResourceId = $subnetId}
                    )
                    $result = $? ? "DataGuard network configuration removed for: " + $storageAccount.StorageAccountName  : "Something went wrong trying to remove network configuration in: " + $storageAccount.StorageAccountName
                    Write-Host $result
                }
            }
        }           
}

if ($tenantId -ne ""){
    Get-AzSubscription -TenantId $tenantId | Where-Object {$_.HomeTenantId -eq $tenantId} | ForEach-Object {
        Set-AzContext -Subscription $_
        if ($action -eq "create"){
            Create
        }
        else {
            Remove
        }
    }
}
elseif ($subscriptionsList -ne $null) {
    $subscriptionsList | ForEach-Object {
        Set-AzContext -Subscription $_
        if ($action -eq "create"){
            Create
        }
        else {
            Remove
        }
    }          
}