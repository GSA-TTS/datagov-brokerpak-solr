#!/bin/bash

# Borrowed/Extended from: https://alestic.com/2016/09/aws-route53-wipe-hosted-zone/
VERBOSE=false

for domain_to_delete in "$@"; do
  # Pass in the domain to delete based on input list
  echo $domain_to_delete

  # Grab the zone id
  hosted_zone_id=$(
    aws route53 list-hosted-zones \
      --output text \
      --query 'HostedZones[?Name==`'$domain_to_delete'.`].Id'
  )

  if [ -z $hosted_zone_id ]; then
    echo "Calculating...No such domain...no work to do! YAY!"
    continue
  fi

  echo hosted_zone_id=$hosted_zone_id

  # Delete all Records from the domain
  echo -n "Deleting records..."
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
        --output text --query 'ChangeInfo.Id' > /tmp/delete-route53
      $VERBOSE && cat /tmp/delete-route53
    fi
  done
  echo "ok"

  echo -n "Disabling DNSSEC..."
  # https://docs.aws.amazon.com/cli/latest/reference/route53/disable-hosted-zone-dnssec.html
  aws route53 disable-hosted-zone-dnssec --hosted-zone-id $hosted_zone_id > /tmp/delete-route53
  echo "ok"
  $VERBOSE && cat /tmp/delete-route53

  echo -n "Deactivating KSK..."
  # https://docs.aws.amazon.com/cli/latest/reference/route53/deactivate-key-signing-key.html
  aws route53 deactivate-key-signing-key --hosted-zone-id $hosted_zone_id --name $domain_to_delete > /tmp/delete-route53
  echo "ok"
  $VERBOSE && cat /tmp/delete-route53

  echo -n "Deleting KSK..."
  # https://docs.aws.amazon.com/cli/latest/reference/route53/delete-key-signing-key.html
  aws route53 delete-key-signing-key --hosted-zone-id $hosted_zone_id --name $domain_to_delete > /tmp/delete-route53
  echo "ok"
  $VERBOSE && cat /tmp/delete-route53

  echo -n "Deleting zone..."
  aws route53 delete-hosted-zone --id $hosted_zone_id > /tmp/delete-route53
  echo "ok"
  $VERBOSE && cat /tmp/delete-route53
done
