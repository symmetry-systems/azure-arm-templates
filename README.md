# azure-templates

Azure deployment templates to bring up and configure the dataguard landing zone in the customer Azure environment. The dataguard services can then be installed in this landing zone.

NOTE: The `Deploy to Azure` button does not work on Gitlab due to this CORS related [issue](https://gitlab.com/gitlab-org/gitlab/-/issues/16732).
Therefore the deploy to azure button points to the public copy of this repo on Github. Eventually we can move these scripts to some other publicly accessible location, say S3, but it will involve the hassle of always keeping the repo, s3, and links in sync.

## Dataguard Environment Setup

### Prerequisites
1. A user with `AAD Global Administrators` to deploy this template.
2. Follow the steps [here](https://github.com/Azure/Enterprise-Scale/blob/individual/docs/EnterpriseScale-Setup-azure.md) to configure deploying user's permissions for ARM tenant deployment.
3. Follow [these steps](#how-to-get-billing-account-name) collect the following information from your Azure environment as it will be used in the deployment:
    * Billing Account Id 
    * Billing Profile Id
    * Invoice Section Id
    * Subscription Ids for which activities are to be monitored by Dataguard

| Step | Description | ARM Template |
|------| ------------| ------------ |

| Create a dataguard subscription | Creates a new dataguard subscription. This step can be skipped if a suitable subscription already exists. In either case note down the id for subscription created above (or existing) and use it to deploy the following template into that subscription.| [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-create-dataguard-subscription.json)|

| Create a symmetry guest user / app registration for administrative access to the subscription. | This user is needed so that dataguard services can be deployed and administered in the dataguard VNet/VMs. | - |

| Create a resource group | Create a resource group in the above subscription | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-create-dataguard-resource-grp.json)

| Create a Virtual Network | Create a virtual network where dataguard VM and Bastion host will live | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-create-virtual-network.json)

| Create a private storage account | Create a storage account in dataguard subscription and a private endpoint to it from the dataguard VNet | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-create-storage-account.json)


| Create a managed identity | Create a managed identity in the dataguard subscription and assign it the contributor role for the dataguard subscription| [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-create-managed-id-assign-contrib.json)

| Assign AD read permission to dataguard managed ID | Run [this script](scripts/configure-ad-settings.ps1) to assign AD read roles to the managed identity and configure archiving of AD audit events. Login: `Connect-AzAccount` , `Connect-AzureAD` and then `./configure-ad-settings.ps1 -TenantID '<your tenant id here>' -SubscriptionName '<Template Created DG Subscription>' -ManagedIdentityName <template-created-dg-id> -ResourceGroupName <dataguard-resource-grp>` | . |

| Assign reader role to MI for ALL other subscriptions (Recommended) | Assign reader role to dataguard managed identity to read resource level information for all other subscriptions in the account. NOTE: this only give read access for control plane data (`actions`) and not any data plane access (`data actions`).| [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-assign-reader-at-root.json)

| Assigne reader role to MI for SELECTED subscriptions (Optional) | Assign reader role to dataguard managed identity to read resource level information for selected subscriptions in the account. NOTE: this only give read access for control plane data (`actions`) and not any data plane access (`data actions`).| [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-assign-reader-at-subscriptions.json)

| Create activity logs diagnostics settings for subscriptions | Activity logs allow dataguard to keep itself updated on the activities happening at the control plane level (resource creation, updation, deletion etc) for a subscription. For internal resource level view enable resource log diagnostics for inidividual resources | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-create-subs-diagnostics.json)

| Create a bastion host in dataguard VNet | Create a bastion host in dataguard VNet | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-create-bastion.json)

| Create a VM for Dataguard services | Create a VM for Dataguard services. Generate SSH Key pair for the VM. Follow steps outlined [here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys) | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fcreate-vm-in-a-vnet.json)

For Olympus:
Assign blob data reader and cosmos data reader roles at subscription level to the dataguard application identity: [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Findividual%2Ftemplates%2Fstandalone%2Fsetup-assign-data-roles-at-subscription.json)

## How to Get Billing Account Name
1. [Signin](https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-7.1.0) with Azure Powershell (signin user should have access to billing information).
2. Run [this script](scripts/fetch-billing-accounts.ps1) after login and note down the relevant billing information. It will produce information about different billing sections and subscriptions, note down the billing informatation you want to use for creating a new subscription for dataguard.
Also note down all the subscription Ids you want dataguard to read activity logs for.
```
===============================
Billing Information
===============================

Option 1
	 Billing Account Id: aaaaaaaa-1111-1111-1111-1111aaaabbbb:cccc2222-1111-2222-3333-eeeeffff1111_2019-01-01
	 Billing Profile Id: YAAA-XXXX-YYY-PPP   	 (Name: Bhimsen Joshi)
	 Invoice Section Id: NNNN-OOOO-PPP-GGG   	 (Name: Joshi Profile)

Option 2
	 Billing Account Id: aaaaaaaa-1111-1111-1111-1111aaaabbbb:cccc2222-1111-2222-3333-eeeeffff1111_2019-01-01
	 Billing Profile Id: YAAA-XXXX-YYY-PPP   	 (Name: Bhimsen Joshi)
	 Invoice Section Id: BBBB-TTTT-UUU-KKK   	 (Name: Bhimsen Profile)

===============================
Subscriptions Information
===============================

Name                             Id                                   TenantId                             State
----                             --                                   --------                             -----
Azure subscription 1             xxxxaaaa-bbbb-cccc-dddd-aaaa11111111 aaaaaaaa-bbbb-cccc-dddd-1234567890ab Enabled
Azure subscription 2             xxxxaaaa-bbbb-cccc-dddd-aaaa11111112 aaaaaaaa-bbbb-cccc-dddd-1234567890ab Enabled
Azure subscription 3             xxxxaaaa-bbbb-cccc-dddd-aaaa11111113 aaaaaaaa-bbbb-cccc-dddd-1234567890ab Enabled

```

## Useful references

1. Creating subscriptions with ARM templates. [link](https://techcommunity.microsoft.com/t5/azure-governance-and-management/creating-subscriptions-with-arm-templates/ba-p/1839961)
2. [link](https://stackoverflow.com/questions/63478559/how-to-deploy-arm-template-with-user-managed-identity-and-assign-a-subscription)
