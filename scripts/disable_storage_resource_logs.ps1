param(
    [string]$tenantId # The Tenant ID where DataGuard is deployed.
)

$DiagnosticSettingName = "dataguard-resouce-diagnostics"

Get-AzSubscription -TenantId $tenantId | Where-Object {$_.HomeTenantId -eq $tenantId} | ForEach-Object {
    $_ | Set-AzContext
    Get-AzStorageAccount | ForEach-Object {
        $storageaccount = $_
        Write-Host 'Removing resource diagnostic settings: ' $DiagnosticSettingName ' for storage account: ' $storageaccount.Id
        $ResourceId = $storageaccount.Id
        $Ids = @(
                $ResourceId + "/blobServices/default"
                $ResourceId + "/fileServices/default"
                $ResourceId + "/queueServices/default"
                $ResourceId + "/tableServices/default"
        )
        $Ids | ForEach-Object {
            Remove-AzDiagnosticSetting -ResourceId $_ -Name $DiagnosticSettingName
        }
    }
}