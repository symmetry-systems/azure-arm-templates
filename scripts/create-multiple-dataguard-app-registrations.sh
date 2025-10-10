#!/bin/bash

declare -a permissions=(
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role"  # Directory.Read.All
    "38d9df27-64da-44fd-b7c5-a6fbac20248f=Role"  # UserAuthenticationMethod.Read.All
    "b0afded3-3588-46d8-8b3d-9842eff778da=Role"  # AuditLog.Read.All
    "332a536c-c7ef-4017-ab91-336970924f0d=Role"  # Sites.Read.All
    "230c1aed-a721-4c5d-9cb4-a90514e508ef=Role"  # Reports.Read.All
    "5e1e9171-754d-478c-812c-f1755a9a4c2d=Role"  # AuditLogsQuery.Read.All
    "19da66cb-0fb0-4390-b071-ebc76a349482=Role"  # InformationProtectionPolicy.Read.All
    "83d4163d-a2d8-4d3b-9695-4ae3ca98f888=Role"  # SharePointTenantSettings.Read.All
)
graphApiId="00000003-0000-0000-c000-000000000000"
secretValues=()

# Add SharePoint-specific permissions
declare -a sharepointPermissions=(
  "d13f72ca-a275-4b96-b789-48ebcc4da984=Role" # Sites.Read.All (SharePoint API)
)
sharepointApiId="00000003-0000-0ff1-ce00-000000000000"

# Login to Azure with Application Administrator user
az login

read -p "Enter the prefix for the DataGuard app registrations: " prefix
read -p "Enter the number of app registrations to create: " numApps
read -p "Enter the Azure Key Vault name: " keyVaultName

for i in $(seq 1 $numApps); do
    appName="$prefix-app-0$i"
    echo "Creating DataGuard app registration: $appName"
    
    #Create App registration
    appId=$(az ad app create --display-name "$appName" --sign-in-audience AzureADMyOrg --query appId --output tsv)
    sleep 5
    echo "DataGuard App created with ID: $appId"

    # Add API permissions
    az ad app permission add --id "$appId" --api "$graphApiId" --api-permissions ${permissions[*]}
    az ad app permission add --id "$appId" --api "$sharepointApiId" --api-permissions ${sharepointPermissions[*]}
    echo "Added permissions to: $appName"
    sleep 15
    
    # Grant admin consent
    az ad app permission admin-consent --id "$appId"
    echo "Admin consent granted for: $appName"
    sleep 5

    # Create a client secret
    echo "Creating client secret for: $appName"
    secretValue=$(az ad app credential reset --id "$appId" --display-name "DefaultSecret" --query password --output tsv)
    echo "Client secret created for: $appName"
    sleep 5

    # Append the secret value to our array
    secretValues+=("$secretValue")

done

combinedSecrets=$(IFS=','; echo "${secretValues[*]}")
combinedSecretName="$prefix-combined-$numApps-secret"

echo "List of DataGuard App Client Ids: $clientIds"
echo "Concatenated list of secrets: $combinedSecrets"

#Switch to managed identity creds (with access to keyvault)
az account clear
az login --identity --allow-no-subscriptions

echo "Storing combined client secrets in Key Vault as: $combinedSecretName"
az keyvault secret set --vault-name "$keyVaultName" --name "$combinedSecretName" --value "$combinedSecrets" --output none
echo "Combined client secret stored in Key Vault: $combinedSecretName"

echo "All DataGuard app registrations completed successfully!"