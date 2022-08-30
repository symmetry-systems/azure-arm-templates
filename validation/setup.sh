#!/usr/bin/env bash

sudo apt install python3.8-venv
mkdir -p validation && cd validation
python3 -m venv venv
. venv/bin/activate

pip install azure-identity>=1.5.0
pip install azure-mgmt-authorization==2.0.0
pip install azure-mgmt-cosmosdb==6.4.0
pip install azure-mgmt-managementgroups==1.0.0
pip install azure-mgmt-resource==20.0.0
pip install azure-mgmt-sql==3.0.1
pip install azure-mgmt-storage==19.1.0
pip install azure-storage-blob>=12.9.0
pip install azure-cosmos
pip install msgraph-core>=0.2.2

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --identity
