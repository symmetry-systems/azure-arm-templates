#!/bin/bash

#Script to create or remove DataGuard's Azure Diagnostic Settings from selected Subscriptions.

SAVEIFS=$IFS
IFS=";"
LOGS='[{"category": "Administrative","enabled": true},{"category": "Security","enabled": true},{"category": "ServiceHealth","enabled": true},{"category": "Alert","enabled": true},{"category": "Recommendation","enabled": true},{"category": "Policy","enabled": true},{"category": "Autoscale","enabled": true},{"category": "ResourceHealth","enabled": true}]'
ACTION=""
DIAGNOSTIC_NAME=""
STORAGE_ACCOUNT_ID=""

while getopts "n:s:t:" flag; do
    case "${flag}" in
        s) SUBS=$(cat ${OPTARG} | sed 's/,/;/g');;
        t) STORAGE_ACCOUNT_ID=${OPTARG};;
        n) DIAGNOSTIC_NAME=${OPTARG};;
        *) echo -e 'Unknown option \n -n | Diagnostic Setting name \n -s | Subscriptions list file path \n -t | Target Storage Account resource ID'; exit 1;;
    esac
done

shift $(( OPTIND - 1 ))

case "$@" in
    create) ACTION="create";;
    delete) ACTION="delete";;
    *) echo "Incorrect or missing argument. Must be 'create' or 'delete'." ; exit 1;;
esac

if [[ "${ACTION}" == "create" ]]; then
    for s in $SUBS; do
        echo "Creating diagnostic setting from Azure Subscription $s"
        az monitor diagnostic-settings create --name ${DIAGNOSTIC_NAME} --resource /subscriptions/$(echo "$s" | tr -d '"') --storage-account $STORAGE_ACCOUNT_ID --logs $LOGS --resource-group abc 2>&1 | tee -a diagnostic_settings_script-log.txt
        echo "Done"
    done
elif [[ "${ACTION}" == "delete" ]]; then
    for s in $SUBS; do
        echo "Deleting diagnostic setting from Azure Subscription $s"
        az monitor diagnostic-settings delete --name ${DIAGNOSTIC_NAME} --resource /subscriptions/$(echo "$s" | tr -d '"') 2>&1 | tee -a diagnostic_settings_script-log.txt
        echo "Done"
    done
fi
