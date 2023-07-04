#!/bin/bash
for s in $(az account list | jq '.[] | .id'); do
    SUBS+=$s
done
echo $SUBS | sed 's/""/","/g' > subscriptions-list.txt