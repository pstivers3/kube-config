#!/bin/bash

let i=1
nodegroup_name=$(aws eks --profile dev list-nodegroups --cluster-name dev-test-2 \
    --region us-west-1  |  awk '{ print $2}' | sed -n "$i p")                       
while [ -n "$nodegroup_name" ]; do # while not null
    echo "node group name: $nodegroup_name"
    (( i++ ))
    nodegroup_name=$(aws eks --profile dev list-nodegroups --cluster-name dev-test-2 \
        --region us-west-1 | awk '{ print $2}' | sed -n "$i p")
done 

