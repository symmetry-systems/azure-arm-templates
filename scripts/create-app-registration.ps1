param([string] $appName)
Install-Module AzureAD 
Import-Module AzureAD
Connect-AzureAD 
New-AzureADApplication -DisplayName $appName