<#
    .Synopsis
        
    .Description
        
#>
param(
    [string]$TenantID,
    [string]$SubscriptionName,
    [string]$ResourceGroupName
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

 if (-not $ValidData) 
 {
    Write-Host "Please rerun this script and pass valid parameters."                 
    return   
 } 

# Install the module if needed: Install-Module AzureAD
# Install-Module Microsoft.Graph -Scope CurrentUser
# Import-Module Microsoft.Graph

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
$ruleName = "dataguard-ad-diag-setting"

Write-Host "Setting subscription: $($SubscriptionName)"


$StorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName
$storageAccountId = $StorageAccount.Id

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
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
          "category": "SignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
          "category": "ServicePrincipalSignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "ManagedIdentitySignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "ProvisioningLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "ADFSSignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "RiskyUsers",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "UserRiskEvents",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
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