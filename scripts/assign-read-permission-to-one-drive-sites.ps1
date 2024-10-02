<# 
    .Synopsis
        Assign read access to OneDrive sites for DataGuard reader application registration.
    .Description
        This script will prompt for necessary fields such as Tenant ID, OneDrive site names, and Reader Application Registration client ID, 
        and then assign or remove read access to the OneDrive sites using Microsoft Graph APIs.
#>

param(
  [string]$tenantId,            # The Azure Tenant ID
  [string[]]$oneDriveSiteNames, # List of OneDrive Site names
  [string]$clientId,            # The DataGuard reader Application Registration client ID
  [string]$outputFile = "DataGuardGrantedAccessSites.txt",  # Output file for granted site names
  [string]$action # Specify either to 'assign' or 'remove' read permission to onedrive sites.
)

# Prompt for Tenant ID if not provided
if (-not $tenantId) {
    $tenantId = Read-Host "Enter the Azure Tenant ID"
}

# Prompt for OneDrive site names if not provided
if (-not $oneDriveSiteNames) {
    $oneDriveSiteNames = @()
    do {
        $siteName = Read-Host "Enter a OneDrive site name (type 'done' when finished)"
        if ($siteName -ne 'done') {
            $oneDriveSiteNames += $siteName
        }
    } while ($siteName -ne 'done')
}

# Prompt for Application client ID if not provided
if (-not $clientId) {
    $clientId = Read-Host "Enter the Application (Client) ID"
}

if (-not $action) {
    $action = Read-Host "Enter the script action ('assign' or 'remove')"
}

if ($action -notin @('assign', 'remove')) {
    Write-Host "Invalid action specified. Please enter either 'assign' or 'remove'." -ForegroundColor Red
    exit 1
}

# Function to get OneDrive site ID by site path (name string)
function Get-SiteIdByName {
    param (
        [string]$siteName
    )

    $rootSite = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/root"
    $domain = $rootSite.siteCollection.hostname

    $site = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/${domain}:/sites/$siteName"
    return $site.id
}

# Function to assign read access to a OneDrive site for the application
function Grant-ReadAccess {
    param (
        [string]$siteName,
        [string]$siteId,
        [string]$appId
    )
    $body = @{
        roles = @("read")
        grantedToIdentities = @(
            @{
                application = @{
                    id = $appId
                    displayName = "Granting read access to DataGuard"
                }
            }
        )
    }
    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/permissions" -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json"
    $result = $? ? "DataGuard permission added successfully in: " + $siteName  : "Something went wrong trying to add DataGuard permission in: " + $siteName
    Write-Host $result
    $result | Out-File -Append $outputFile
}

function Remove-ReadAccess {
    param (
        [string]$siteName,
        [string]$siteId,
        [string]$appId
    )

    $permissions = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/permissions"

    # Match permission for DataGuard application
    $permissionToRemove = $permissions.value | Where-Object { 
        $_.grantedToIdentities[0].application.id -eq $appId
    }

    if ($permissionToRemove -ne $null) {
        $permissionId = $permissionToRemove.id
        
        Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/permissions/$permissionId"
        
        $result = $? ? "DataGuard permission removed successfully in: " + $siteName  : "Something went wrong trying to remove DataGuard permission in: " + $siteName
        Write-Host $result
        $result | Out-File -Append $outputFile

    } else {
        Write-Host "No permission found for app: $appId on site: $siteName"
    }
}


#Connect to Microsoft Graph API (If not present in tenant it will ask to be added and grant admin consent)
$scopes = "Sites.FullControl.All"
Connect-MgGraph -Scopes $scopes -TenantId $tenantId

$grantedSiteNames = @()

# Iterate each site name provided, get the site ID and grant read access.
foreach ($siteName in $oneDriveSiteNames) {
    try {
        $siteId = Get-SiteIdByName -siteName $siteName
        if ($action -eq "assign"){
            Write-Host "Granting DataGuard read access to site: $siteName (ID: $siteId)"
            Grant-ReadAccess -siteName $siteName -siteId $siteId -appId $clientId
        }
        else {
            Write-Host "Removing DataGuard read access to site: $siteName (ID: $siteId)"
            Remove-ReadAccess -siteName $siteName -siteId $siteId -appId $clientId
        }

    }
    catch {
        Write-Host "Failed to process site: $siteName" -ForegroundColor Red
    }
}

Disconnect-MgGraph