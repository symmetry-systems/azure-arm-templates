param(
    [string]$appName,
)
Connect-AzureAD
New-AzureADApplication -DisplayName $appName
