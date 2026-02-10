#!/bin/bash

set -e

CLUSTER=$(curl ${ECS_CONTAINER_METADATA_URI}/task | jq -r .Cluster)
TASK_ARN=$(curl ${ECS_CONTAINER_METADATA_URI}/task | jq -r .TaskARN)
REGION=$(echo $TASK_ARN | cut -d: -f4)

TASK_DETAILS=$(aws ecs describe-tasks --task "${TASK_ARN}" --cluster "${CLUSTER}" --query 'tasks[0].attachments[0].details')
ENI=$(echo $TASK_DETAILS | jq -r '.[] | select(.name=="networkInterfaceId").value')
SERVER_ADDRESS=$(aws ec2 describe-network-interfaces --network-interface-ids "${ENI}" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

cat > changes.json <<- EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$REGION.hookshot-matchmaker.cowboyscott.games",
        "Type": "A",
        "TTL": 5,
        "ResourceRecords": [
          {
            "Value": "$SERVER_ADDRESS"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "hookshot-matchmaker.cowboyscott.games",
        "Type": "A",
        "SetIdentifier": "$REGION",
        "Region": "$REGION",
        "TTL": 5,
        "ResourceRecords": [
          {
            "Value": "$SERVER_ADDRESS"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id Z056553122XOBPCXIJCVN --change-batch file://changes.json

./matchmaker