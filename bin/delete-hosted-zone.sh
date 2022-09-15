#!/bin/bash

# Borrowed/Extended from: https://alestic.com/2016/09/aws-route53-wipe-hosted-zone/

# Pass in the domain to delete
domain_to_delete=$1

# Grab the zone id
hosted_zone_id=$(
  aws route53 list-hosted-zones \
    --output text \
    --query 'HostedZones[?Name==`'$domain_to_delete'.`].Id'
)
echo hosted_zone_id=$hosted_zone_id

if [ -z $hosted_zone_id ]; then
  echo "Calculating...No such domain...no work to do! YAY!"
  exit 0
fi

# Delete all Records from the domain
aws route53 list-resource-record-sets \
  --hosted-zone-id $hosted_zone_id |
jq -c '.ResourceRecordSets[]' |
while read -r resourcerecordset; do
  read -r name type <<<$(echo $(jq -r '.Name,.Type' <<<"$resourcerecordset"))
  if [ $type != "NS" -a $type != "SOA" ]; then
    aws route53 change-resource-record-sets \
      --hosted-zone-id $hosted_zone_id \
      --change-batch '{"Changes":[{"Action":"DELETE","ResourceRecordSet":
          '"$resourcerecordset"'
        }]}' \
      --output text --query 'ChangeInfo.Id'
  fi
done

# Disable DNSSEC
# https://docs.aws.amazon.com/cli/latest/reference/route53/disable-hosted-zone-dnssec.html
aws route53 disable-hosted-zone-dnssec --hosted-zone-id $hosted_zone_id

# Deactivate KSK
# https://docs.aws.amazon.com/cli/latest/reference/route53/deactivate-key-signing-key.html
aws route53 deactivate-key-signing-key --hosted-zone-id $hosted_zone_id --name $domain_to_delete

# Delete KSK
# https://docs.aws.amazon.com/cli/latest/reference/route53/delete-key-signing-key.html
aws route53 delete-key-signing-key --hosted-zone-id $hosted_zone_id --name $domain_to_delete

# Delete domain zone
aws route53 delete-hosted-zone --id $hosted_zone_id
