#! /bin/bash

usage="Usage:   ./upgrade-cluster.sh <cluser name> <kubernetes version> [--prod]"
example="Example: ./upgrade-cluster.sh dev-test-2 1.19"

help_status=$1

if [ "$help_status" = help ] || [ "$help_status" = -h ] || [ "$help_status" = --help ]; then
    echo -e "\n$usage\n$example"
    exit 1
fi

region=us-west-1
prod_account_id=<account ID here>
dev_account_id=<account ID here>
cluster_name=$1
version=$2
account_option=$3

# verify the user wants to operate on the production account
if [ "$account_option" = --prod ]; then
    read -p "Are you sure you want to upgrade a cluster in Production? y/n " answer
    case $answer in
        [Yy]* ) account_id=$prod_account_id; profile=prod; echo;;
        [Nn]* ) echo "exiting"; exit;;
         * ) echo "Please answer y or n.";;
    esac
else
    account_id=$dev_account_id
    profile=dev
fi
echo -e "Using AWS profile $profile, account ID $account_id"

# set the context and ensure it exists locally 
# this is also a validation check on the variables
kubectl config use-context "arn:aws:eks:${region}:${account_id}:cluster/${cluster_name}"
if [ $? -ne 0 ]; then
    echo -e "\nCurrent cluster versions in account $account_id region $region are:"
    eksctl get cluster --profile $profile --region us-west-1 -o yaml | grep name
    echo -e "\n$usage\n$example\n"
    echo "exiting"
    exit $?
fi

function report_versions {
    control_plane_version=$(aws eks describe-cluster --profile "$profile" --name "$cluster_name" --region "$region" --query 'cluster.version')
    echo "control plane version: v$control_plane_version"
    kubectl get daemonset kube-proxy --namespace kube-system \
        -o=jsonpath='{$.spec.template.spec.containers[:1].image}' | cut -d "/" -f3
    kubectl describe deployment coredns --namespace kube-system | grep Image | cut -d "/" -f3
}

# function to upgrade the cluster
function upgrade_cluster {
    echo -e "\n*** upgrading the cluster"
    eksctl upgrade cluster --profile "$profile" --name "$cluster_name" --version "$version" --region "$region" --approve
    if [ $? -ne 0 ]; then
        echo "exiting"
        exit $?
    fi

    echo -e "\n*** updating kubeproxy\n"
    eksctl utils update-kube-proxy --cluster "$cluster_name" --region "$region" --approve

    echo -e "\n*** updating coredns\n"
    eksctl utils update-coredns --cluster "$cluster_name" --region "$region" --approve

    echo -e "\nfound nodegroups:"
    aws eks --profile "$profile" list-nodegroups --cluster-name "$cluster_name" --region "$region" | awk '{ print $2}'

    # get the nodegroup names one at a time and upgrade the node groups
    let i=1
    while true; do
        nodegroup_name=$(aws eks --profile "$profile" list-nodegroups --cluster-name "$cluster_name" \
            --region "$region" | awk '{ print $2}' | sed -n "$i p")
        if [ -z "$nodegroup_name" ]; then
            break
        fi 
        echo -e "\n*** upgrading nodegroup $nodegroup_name to v$version\n"
        eksctl upgrade nodegroup --profile "$profile" --name "$nodegroup_name" --cluster "$cluster_name" \
            --kubernetes-version "$version" --region "$region"
        (( i++ ))
    done
    
    # report versions after upgrade
    echo -e "\nCurrent versions after upgrade:"
    report_versions
}

# report versions before upgrade
echo -e "\nCurrent versions before upgrade:"
report_versions
echo

# if user answers y, upgrade the cluster
read -p "Do you want to proceed to upgrade the cluster to version ${version}? y/n " answer
case $answer in
    [Yy]* ) upgrade_cluster;;
    [Nn]* ) echo "exiting"; exit;;
     * ) echo "Please answer y or n.";;
esac

