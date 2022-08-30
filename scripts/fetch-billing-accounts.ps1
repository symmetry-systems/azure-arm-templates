<#
    .Synopsis
        Get all the billing scopes the authenticated user has access to
    .Description
        This script will retrive the billing accounts and enrollment accounts the authenticated user has access to.
        
        The information is needed to determine the billingScope property value when creating a subscription via the
        Microsoft.Subscription/aliases resource.  Nothing will be returned from the script if the user does not have
        access to any billing or enrollment accounts.
        The script can be used for an Enterprise Agreement account, for other agreements the script will need to be modified.
#>

$billingAccountPath = "/providers/Microsoft.Billing/billingaccounts/?api-version=2020-05-01"
$billingAccounts = ($(Invoke-AzRestMethod -Method "GET" -path $billingAccountPath).Content | ConvertFrom-Json).value
$Tab = [char]9
Write-Host "==============================="
Write-Host "Billing Information"
Write-Host "==============================="
Write-Host "  "
foreach ($ba in $billingAccounts) {
    # Write-Host "Billing Account: $($ba.name)"
    $invoiceSectionsUri = "/providers/Microsoft.Billing/billingAccounts/$($ba.name)/listInvoiceSectionsWithCreateSubscriptionPermission?api-version=2019-10-01-preview"
    $invoiceSections = ($(Invoke-AzRestMethod -Method "POST" -path $invoiceSectionsUri).Content | ConvertFrom-Json).value
    $i = 0
    foreach($section in $invoiceSections){
        $i = $i + 1
        Write-Host "Option $($i)"
        Write-Host "$Tab Billing Account Id: $($ba.name)"
        Write-Host "$Tab Billing Profile Id: $($section.billingProfileSystemId)   $Tab (Name: $($section.billingProfileDisplayName))"
        Write-Host "$Tab Invoice Section Id: $($section.invoiceSectionSystemId)   $Tab (Name: $($section.invoiceSectionDisplayName))"
        Write-Host "  "
    }   
}
Write-Host "==============================="
Write-Host "Subscriptions Information"
Write-Host "==============================="
Get-AzSubscription
