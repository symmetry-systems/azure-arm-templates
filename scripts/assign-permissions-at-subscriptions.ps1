<#
    .Synopsis
        Allow Dataguard Read access to Azure Subscriptions.
    .Description
        This script will iterate through all the specified subscriptions and assign Read and Data Read Access for DataGuard.
#>
param(
  [string]$tenantId, # The Customer Tenant
  [string[]]$subscriptionsList, # The Customer Subscription IDs List.
  [string]$principalId, # The dataguard principal id.
  [string]$action # Specify either to 'assign' or 'remove' the defined network configuration rule.
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

if (-not $principalId) {
    $principalId = Read-Host "Enter the DataGuard principal ID"
}

if (-not $action) {
    $action = Read-Host "Enter the script action ('assign' or 'remove')"
}

if ($action -notin @('assign', 'remove')) {
    Write-Host "Invalid action specified. Please enter either 'assign' or 'remove'." -ForegroundColor Red
    exit 1
}

function Assign {
    param (
        [string]$subscriptionId
    )
    Write-Host "Assigning permissions..."
    New-AzRoleAssignment -Scope "/subscriptions/$subscriptionId" -RoleDefinitionName "Reader" -ObjectId $principalId
    New-AzRoleAssignment -Scope "/subscriptions/$subscriptionId" -RoleDefinitionName "Storage Blob Data Reader" -ObjectId $principalId
}

function Remove {
    param (
        [string]$subscriptionId
    )
    Write-Host "Removing permissions..."
    Remove-AzRoleAssignment -Scope "/subscriptions/$subscriptionId" -RoleDefinitionName "Reader" -ObjectId $principalId
    Remove-AzRoleAssignment -Scope "/subscriptions/$subscriptionId" -RoleDefinitionName "Storage Blob Data Reader" -ObjectId $principalId
}

if ($tenantId -ne ""){
    Get-AzSubscription -TenantId $tenantId | Where-Object {$_.HomeTenantId -eq $tenantId} | ForEach-Object {
        Set-AzContext -Subscription $_
        if ($action -eq "assign"){
            Assign -subscriptionId $_
        }
        else {
            Remove -subscriptionId $_
        }
    }
}
elseif ($subscriptionsList -ne $null) {
    $subscriptionsArray = $subscriptionsList -split ','
    $subscriptionsArray | ForEach-Object {
        Set-AzContext -Subscription $_
        if ($action -eq "assign"){
            Assign -subscriptionId $_
        }
        else {
            Remove -subscriptionId $_
        }
    }          
}