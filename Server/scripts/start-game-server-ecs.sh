#!/bin/bash

set -e

CLUSTER=$(curl ${ECS_CONTAINER_METADATA_URI}/task | jq -r .Cluster)
TASK_ARN=$(curl ${ECS_CONTAINER_METADATA_URI}/task | jq -r .TaskARN)

TASK_DETAILS=$(aws ecs describe-tasks --task "${TASK_ARN}" --cluster "${CLUSTER}" --query 'tasks[0].attachments[0].details')
ENI=$(echo $TASK_DETAILS | jq -r '.[] | select(.name=="networkInterfaceId").value')
SERVER_ADDRESS=$(aws ec2 describe-network-interfaces --network-interface-ids "${ENI}" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

SERVER_ADDRESS=$SERVER_ADDRESS ./hookshot.x86_64 --display-driver headless --server