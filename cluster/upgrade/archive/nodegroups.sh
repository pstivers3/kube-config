#!/bin/bash

let i=1
while true; do
    nodegroup_name=$(aws eks --profile dev list-nodegroups --cluster-name dev-test-2 \
        --region us-west-1 | awk '{ print $2}' | sed -n "$i p")
    if [ -z "$nodegroup_name" ]; then
        break
    fi
    echo "node group name: $nodegroup_name"
    (( i++ ))
done 

echo "done"
