$subscriptions = @()
Connect-AzAccount
foreach ($sub in (Get-AzSubscription).Id) {
        $subscriptions += '"'+$sub+'"'
}
$subscriptions -join ',' | Out-File "~/subscription-ids.txt"