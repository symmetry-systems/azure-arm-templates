
param(
  [string]$TenantId, # The Tenant ID where DataGuard is deployed.
  [string]$ManagedDataGuardIdentity, # The name of the managed DataGuard identity.
)
  
# Microsoft Graph App ID. This is constant.
$GraphAppId = "00000003-0000-0000-c000-000000000000"

# DataGuard requires read access to Azure AD to collect identity metadata.
$PermissionName = "Domain.Read.All" 

# Install the module (You need admin on the machine)
Install-Module AzureAD 

Connect-AzureAD -TenantId $TenantID 
$MSI = (Get-AzureADServicePrincipal -Filter "displayName eq '$ManagedDataGuardIdentity'")
Start-Sleep -Seconds 10
$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"
$AppRole = $GraphServicePrincipal.AppRoles | `
Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId `
-ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
