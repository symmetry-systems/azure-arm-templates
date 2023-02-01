#!/bin/bash

#Script to create or remove DataGuard's DataGuard Role Assigments from selected Subscriptions.

SAVEIFS=$IFS
IFS=";"
ROLES='{"name": "Storage Blob Data Reader", "id": "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"};{"name": "Reader", "id": "acdd72a7-3385-48ef-bd42-f606fba81ae7"}'
APP_ID="" #Object ID of the Enterprise Application
SUBS="" #List of Subscriptions

while getopts "s:i:" flag; do
    case "${flag}" in
        s) SUBS=$(cat ${OPTARG} | sed 's/,/;/g');;
        i) APP_ID=${OPTARG};;
        *) echo -e 'Unknown option \n -i Enterprise Application object ID \n -s | Subscriptions list file path'; exit 1;;
    esac
done

shift $(( OPTIND - 1 ))

case "$@" in
    assign) ACTION="assign";;
    remove) ACTION="remove";;
    *) echo "Incorrect or missing argument. Must be 'assign' or 'remove'."; exit 1;;
esac

if [[ "${ACTION}" == "assign" ]]; then
    for s in $SUBS; do
        for r in $ROLES; do
        echo "Assigning $(echo "$r" | jq '. | .name') role for Azure Subscription $s"
        az role assignment create --assignee-object-id $APP_ID --assignee-principal-type ServicePrincipal --role $(echo "$r"  | jq '. | .id' | sed 's/"//g') --scope /subscriptions/$(echo "$s" | tr -d '"') 2>&1 | tee -a level_one_permissions_script-log.txt
        echo "Done"
        done
    done
elif [[ "${ACTION}" == "remove" ]]; then
    for s in $SUBS; do
        for r in $ROLES; do
        echo "Removing $(echo "$r" | jq '. | .name') role for Azure Subscription $s"
        az role assignment delete --assignee $APP_ID --role $(echo "$r"  | jq '. | .name' | sed 's/"//g') --scope /subscriptions/$(echo "$s" | tr -d '"') 2>&1 | tee -a level_one_permissions_script-log.txt
        echo "Done"
        done
    done
fi
