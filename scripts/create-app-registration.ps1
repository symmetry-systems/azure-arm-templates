<#
    .Synopsis
        Create app registration on AD 
    .Description
        
#>

param(
    [string]displayName,
)


$ValidData = $true
if(-not $TenantID)
 {
     Write-Host "displayName is null."
     $ValidData = $false
 }

Connect-AzAccount
Connect-AzureAD -TenantId $TenantID -erroraction 'silentlycontinue'
Write-Host "Connected to AD..."

