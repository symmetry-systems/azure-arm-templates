
param(
  [string]$TenantId, # The Tenant ID where DataGuard is deployed.
  [string]$AppRegId # The name of the DataGuard App registration.
)
  
# Microsoft Graph App ID. This is constant.
$GraphAppId = "00000003-0000-0000-c000-000000000000"

# DataGuard requires read access to Azure AD to collect identity metadata.
$PermissionNames = "Directory.Read.All", "UserAuthenticationMethod.Read.All"

# Install the module (You need admin on the machine)
Install-Module AzureAD 

Connect-AzureAD -TenantId $TenantId 
Start-Sleep -Seconds 10
$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"
foreach($PermissionName in $PermissionNames){
  $AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
  Add-AzADAppPermission -ObjectId $AppRegId -ApiId $GraphAppId -PermissionId $AppRole.Id -Type 'Role'
}
