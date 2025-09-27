#!/bin/bash

# Define variables


AMI_ID="ami-09c813fb71547fc4f" # Replace with your desired AMI ID
SG_ID="sg-00675114d20e6c402" # Replace with your security group ID
SUBNET_ID="subnet-00830bfb3cc7d5d57"
ZONE_ID="Z0153004248DQ2TZA1JUZ" # Get Hosted zone id from route53 & replace with your ID
DOMAIN_NAME="kubebuilder.space" #Get domain name from route53 & replace with your domain name

for instance in $@ # mongodb redis mysql
do
    INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro --security-group-ids "$SG_ID" --subnet-id "$SUBNET_ID" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" --query 'Instances[0].InstanceId' --output text)

    # Get Private IP
    if [ $instance != "frontend" ]; then
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME" # mongodb.kubebuilder.space
    else
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
        RECORD_NAME="$DOMAIN_NAME" # kubebuilder.space
    fi

    echo "$instance: $IP"

    aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch '
    {
        "Comment": "Updating record set"
        ,"Changes": [{
        "Action"              : "UPSERT"
        ,"ResourceRecordSet"  : {
            "Name"              : "'$RECORD_NAME'"
            ,"Type"             : "A"
            ,"TTL"              : 1
            ,"ResourceRecords"  : [{
                "Value"         : "'$IP'"
            }]
        }
        }]
    }
    '
done

