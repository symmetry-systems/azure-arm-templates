<# 
    .Synopsis
        Assign read access to SharePoint sites for DataGuard reader application registration.
    .Description
        This script will prompt for necessary fields such as Tenant ID, SharePoint site ids, and Reader Application Registration client ID, 
        and then assign or remove read access to the SharePoint sites using Microsoft Graph APIs.
    .Example
        For interactive prompts:
        ./assign-read-permission-to-sharepoint-sites-by-site-id.ps1
        For one-liner command execution:
        ./assign-read-permission-to-sharepoint-sites-by-site-id.ps1 -TenantId TENANT_ID -sharePointSites ("{hostname},{spsite.id},{spweb.id}","{hostname},{spsite.id},{spweb.id}") -clientId "APP_CLIENT_ID" -action "assign"
#>

param(
  [string]$tenantId,            # The Azure Tenant ID
  [string[]]$sharePointSites, # List of SharePoint Site IDs, format "{hostname},{spsite.id},{spweb.id}"
  [string]$clientId,            # The DataGuard reader Application Registration client ID
  [string]$outputFile = "DataGuardGrantedAccessSites.txt",  # Output file for granted sites
  [string]$action # Specify either to 'assign' or 'remove' read permission to sharepoint sites.
)

# Prompt for Tenant ID if not provided
if (-not $tenantId) {
    $tenantId = Read-Host "Enter the Azure Tenant ID"
}

# Prompt for  site names if not provided
if (-not $sharePointSites) {
    $sharePointSites = @()
    do {
        $site = Read-Host "Enter a SharePoint site ID (type 'done' when finished)"
        if ($site -ne 'done') {
            $sharePointSites += $site
        }
    } while ($site -ne 'done')
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

# Get SharePoint site ID by site path
function Get-SiteIdByName {
    param (
        [string]$siteName
    )

    $rootSite = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/root"
    $domain = $rootSite.siteCollection.hostname

    $site = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/${domain}:/sites/$siteName"
    return $site.id
}

# Get SharePoint site name by site ID
function Get-SiteNameById {
    param (
        [string]$siteId
    )
    $site = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/$siteId"
    Write-Host $site.name
    return $site.name
}

# Function to assign read access to a SharePoint site for the application
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
    $result = $? ? "DataGuard permission added successfully in: $siteName (ID: $siteId)": "Something went wrong trying to add DataGuard permission in: $siteName (ID: $siteId)"
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
        
        $result = $? ? "DataGuard permission removed successfully in: $siteName (ID: $siteId)" : "Something went wrong trying to remove DataGuard permission in: $siteName (ID: $siteId)"
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

# Iterate each site name or ID provided.
foreach ($siteInput in $sharePointSites) {
    try {
        $siteName = Get-SiteNameById -siteId $siteInput

        if ($action -eq "assign"){
            Write-Host "Granting DataGuard read access to site: $siteName (ID: $siteInput)"
            Grant-ReadAccess -siteName $siteName -siteId $siteInput -appId $clientId
        }
        else {
            Write-Host "Removing DataGuard read access to site: $siteName (ID: $siteInput)"
            Remove-ReadAccess -siteName $siteName -siteId $siteInput -appId $clientId
        }

    }
    catch {
        Write-Host "Failed to process site: $siteName" -ForegroundColor Red
    }
}
