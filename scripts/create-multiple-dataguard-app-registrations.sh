#!/bin/bash

set -euo pipefail

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

# Add SharePoint-specific permissions
declare -a sharepointPermissions=(
  "d13f72ca-a275-4b96-b789-48ebcc4da984=Role" # Sites.Read.All (SharePoint API)
)
sharepointApiId="00000003-0000-0ff1-ce00-000000000000"

# Ensure an Azure login is active. The signed-in user must have both
# Application Administrator rights (to create app registrations) and Key Vault
# write access on the target vault (to store the shared certificate).
if ! az account show >/dev/null 2>&1; then
    az login
fi

read -p "Enter the prefix for the DataGuard app registrations: " prefix
read -p "Enter the number of app registrations to create: " numApps
read -p "Enter the Azure Key Vault name: " keyVaultName

# Create a working directory and ensure it gets cleaned up on exit
workDir=$(mktemp -d)
trap 'rm -rf "$workDir"' EXIT

keyFile="$workDir/${prefix}-connector-key.pem"
certFile="$workDir/${prefix}-connector-cert.pem"
pfxFile="$workDir/${prefix}-connector.pfx"
pfxB64File="$workDir/${prefix}-connector-pfx-b64.txt"

# Generate a single self-signed certificate shared across all app registrations.
echo "Generating shared certificate..."
openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout "$keyFile" \
    -out "$certFile" \
    -days 1825 \
    -subj "/CN=${prefix}-connector"

# Export to PKCS12 (PFX) with an empty password so DataGuard can load it.
openssl pkcs12 -export \
    -passout pass: \
    -out "$pfxFile" \
    -inkey "$keyFile" \
    -in "$certFile"

# Base64-encode the PFX for storage in Key Vault (cross-platform via openssl).
openssl base64 -A -in "$pfxFile" -out "$pfxB64File"
echo "Shared certificate generated."

clientIds=""

for i in $(seq 1 $numApps); do
    appName="$prefix-app-0$i"
    echo "Creating DataGuard app registration: $appName"

    # Create App registration
    appId=$(az ad app create --display-name "$appName" --sign-in-audience AzureADMyOrg --query appId --output tsv)
    sleep 5
    echo "DataGuard App created with ID: $appId"

    if [ -z "$clientIds" ]; then
        clientIds="$appId"
    else
        clientIds="$clientIds,$appId"
    fi

    # Add API permissions
    az ad app permission add --id "$appId" --api "$graphApiId" --api-permissions ${permissions[*]}
    az ad app permission add --id "$appId" --api "$sharepointApiId" --api-permissions ${sharepointPermissions[*]}
    echo "Added permissions to: $appName"
    sleep 15

    # Grant admin consent
    az ad app permission admin-consent --id "$appId"
    echo "Admin consent granted for: $appName"
    sleep 5

    # Upload the shared certificate to this app registration
    echo "Uploading shared certificate to: $appName"
    az ad app credential reset --id "$appId" --cert "@$certFile" --append --output none
    echo "Certificate uploaded to: $appName"
    sleep 5
done

sharedSecretName="$prefix-shared-certificate"
pfxB64Value=$(cat "$pfxB64File")

echo ""
echo "============================================================"
echo "Client IDs (comma-separated):"
echo "$clientIds"
echo ""
echo "Shared certificate (base64 PFX):"
echo "$pfxB64Value"
echo "============================================================"
echo ""

# Attempt to store the shared certificate in Key Vault. If this fails (e.g.,
# network restrictions, missing permissions), the output above still has
# everything needed for manual configuration.
echo "Storing shared certificate (base64 PFX) in Key Vault as: $sharedSecretName"
if az keyvault secret set --vault-name "$keyVaultName" --name "$sharedSecretName" --file "$pfxB64File" --output none 2>/dev/null; then
    echo "Shared certificate stored in Key Vault: $sharedSecretName"
else
    echo "WARNING: Failed to write to Key Vault '$keyVaultName'."
    echo "Use the base64 PFX value printed above to manually create the secret."
fi

echo ""
echo "All DataGuard app registrations completed successfully!"
echo ""
echo "Client IDs (comma-separated): $clientIds"
echo "Key Vault secret name:        $sharedSecretName"
echo ""
echo "NOTE: All app registrations share the same certificate, so only one Key Vault"
echo "secret is needed. Use the same secret name for every app in the DataGuard"
echo "connector configuration."
