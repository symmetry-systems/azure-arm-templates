param([string] $appName)
Install-Module AzureAD 
Connect-AzureAD 
New-AzureADApplication -DisplayName $appName