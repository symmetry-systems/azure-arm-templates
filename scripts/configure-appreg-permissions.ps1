
param(
  [string]$TenantId, # The Tenant ID where DataGuard is deployed.
  [string]$appName, # The name of the DataGuard App registration.
  [boolean]$multiTenant
)

$ValidData = $true
if(-not $TenantID)
 {
     Write-Host "TenantID was null. "
     $ValidData = $false
 }
 if(-not $appName)
 {
     Write-Host "appName was null. "
     $ValidData = $false
 }
 if(-not $multiTenant)
 {
     Write-Host "multiTenant was null. "
     $ValidData = $false
 }

# Microsoft Graph App ID. This is constant.
$GraphAppId = "00000003-0000-0000-c000-000000000000"

# DataGuard requires read access to Azure AD to collect identity metadata.
$AppPermissionNames = "Directory.Read.All", "UserAuthenticationMethod.Read.All", "User.Read"
$DelegatedPermissionNames = "User.Read" #e1fe6dd8-ba31-4d61-89e7-88639da4683d

# Install the module (You need admin on the machine)
Install-Module AzureAD 

Connect-AzureAD -TenantId $TenantId 
Start-Sleep -Seconds 15

$appReg = New-AzureADApplication -DisplayName $appName -AvailableToOtherTenants $multiTenant

$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"

Start-Sleep -Seconds 5

foreach($PermissionName in $AppPermissionNames){
  $AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
  Add-AzADAppPermission -ObjectId $appReg.ObjectId -ApiId $GraphAppId -PermissionId $AppRole.Id -Type 'Role'
}

foreach($PermissionName in $DelegatedPermissionNames){
  $AppRole = $GraphServicePrincipal.Oauth2Permissions | Where-Object {$_.Value -eq $PermissionName}
  Add-AzADAppPermission -ObjectId $appReg.ObjectId -ApiId $GraphAppId -PermissionId $AppRole.Id -Type 'Scope'
}
