#! /bin/bash

# To declare static Array
arr=(1 Homepage Login Register Profile )

for i in 1 2 3 4
do
	aws ec2 run-instances --image-id ami-00f7e5c52c0f43726 --count 1 --instance-type t2.micro \
--key-name rootkey --subnet-id subnet-05e2325088b3541a9 --security-group-ids 	sg-049a065b86a129031 \
--user-data file://userdata$i.txt --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${arr[$i]}}]" 

	aws elbv2 create-target-group \
    --name TG-${arr[$i]} \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --vpc-id vpc-0c3e4be764e2b6939 \
    --health-check-interval-seconds 5 \
    --health-check-timeout-seconds 2 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \

done

aws ec2 describe-instances --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value[],InstanceId]" --output table
aws elbv2 describe-target-groups --query "TargetGroups[*].{Name:TargetGroupName,ID:TargetGroupArn}" --output table

for i in 1 2 3 4
do
	echo "Enter ARN of Target Group - ${arr[$i]}"
	read tgarn

	echo "Enter ID of Instance - ${arr[$i]}"
	read ec2id
	

	aws elbv2 register-targets --target-group-arn $tgarn --targets Id=$ec2id
	echo -e "\n -------------------------------------------------------\n"

done


aws ec2 describe-security-groups  --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" --output table
aws ec2 describe-subnets --query "Subnets[*].{ID:SubnetId}" --output table

echo "Enter Subnet ID"
read subnet_id subnet_id1 subnet_id2

echo "Enter Security Group ID"
read sg_id;

aws elbv2 create-load-balancer --name "ALB"  \
--subnets $subnet_id $subnet_id1 $subnet_id2 --security-groups $sg_id


aws elbv2 describe-target-groups --query "TargetGroups[*].{Name:TargetGroupName,ID:TargetGroupArn}" --output table
aws elbv2 describe-load-balancers --query "LoadBalancers[*].{Name:LoadBalancerName,ID:LoadBalancerArn}" --output table


ALB_ID=$(aws elbv2 describe-load-balancers --query "LoadBalancers[0].LoadBalancerArn" \
--output text)

ARN=$(aws elbv2 describe-target-groups --query "TargetGroups[0].TargetGroupArn" \
--output text)


listner_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ID  \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$ARN \
	--query 'Listeners[0].ListenerArn' \
	--output text)

aws elbv2 describe-target-groups --query "TargetGroups[*].{Name:TargetGroupName,ID:TargetGroupArn}" --output table
arr1=(1 2 login register profile )


for i in  2 3 4
do 
	echo "Enter ARN of Target Group => [${arr1[$i]}]"
	read tgarn1

cat <<EOF > actions-forward-path.json
[
  {
      "Type": "forward",
      "ForwardConfig": {
          "TargetGroups": [
              {
                  "TargetGroupArn": "$tgarn1"
              }
          ]
      }
  }
]
EOF

cat <<EOF > conditions-path.json
[
  {
      "Field": "path-pattern",
      "PathPatternConfig": {
          "Values": ["*${arr1[$i]}*"]
      }
  }
]
EOF
AWS_ALB_LISTENER_RULE_ARN=$(aws elbv2 create-rule \
    --listener-arn $listner_ARN\
    --priority $i \
    --conditions file://conditions-path.json \
    --actions file://actions-forward-path.json \
    --query 'Rules[0].RuleArn' \
    --output text)
done

 

