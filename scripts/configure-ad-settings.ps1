<#
    .Synopsis
        
    .Description
        
#>
param(
    [string]$TenantID,
    [string]$SubscriptionName,
    [string]$ResourceGroupName,
    [string]$StorageAccountId
)

$ValidData = $true
if(-not $TenantID)
 {
     Write-Host "TenantID was null. "
     $ValidData = $false
 }
 if(-not $SubscriptionName)
 {
     Write-Host "SubscriptionName was null. "
     $ValidData = $false
 }
 if(-not $ResourceGroupName)
 {
     Write-Host "ResourceGroupName was null. "
     $ValidData = $false
 }
 if(-not $StorageAccountId)
 {
     Write-Host "StorageAccountId was null. "
     $ValidData = $false
 }

 if (-not $ValidData) 
 {
    Write-Host "Please rerun this script and pass valid parameters."                 
    return   
 } 

Connect-AzureAD -TenantId $TenantID -erroraction 'silentlycontinue'
Write-Host "Connected to AD..."

Start-Sleep -Seconds 10

Set-AzContext -Tenant $TenantID -Subscription $SubscriptionName

function Get-AzCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'

    $azureRmProfileModuleVersion = (Get-Module Az.Profile).Version
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azureRmProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }

    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
$token = Get-AzCachedAccessToken
$ruleName = "dataguard-managed-id-ad-diag-setting"

Write-Host "Setting subscription: $($SubscriptionName)"

Write-Host "Sending AD Audit logs to storage account: $($storageAccountId)"

$uri = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/{0}?api-version=2017-04-01-preview" -f $ruleName
$body = @"
{
    "id": "providers/microsoft.aadiam/diagnosticSettings/$ruleName",
    "type": null,
    "name": "Storage Account",
    "location": null,
    "kind": null,
    "tags": null,
    "properties": {
      "storageAccountId": "$storageAccountId",
      "serviceBusRuleId": null,
      "workspaceId": null,
      "eventHubAuthorizationRuleId": null,
      "eventHubName": null,
      "metrics": [],
      "logs": [
            {
                "category": "AuditLogs",
                "categoryGroup": null,
                "enabled": true,
                "retentionPolicy": {
                    "days": 0,
                    "enabled": false
                }
            }
      ]
    },
    "identity": null
  }
"@

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

$response = Invoke-WebRequest -Method Put -Uri $uri -Body $body -Headers $headers

if ($response.StatusCode -ne 200) {
    throw "an error occured: $($response | out-string)"

}