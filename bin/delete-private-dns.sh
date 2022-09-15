#!/bin/bash

VERBOSE=false

all_services=$(aws servicediscovery list-services | jq -r ".Services")
all_namespaces=$(aws servicediscovery list-namespaces | jq -r ".Namespaces")

for domain in "$@"; do
  num_of_services=$(echo $all_services | jq -r "length")
  for i in $(seq 0 $num_of_services); do
    service_name=$(echo $all_services | jq .[$i].Name)
    $VERBOSE && echo "Inspecting servicediscovery service...$service_name"
    if [[ $(echo $service_name | cut -c2-9) = $(echo $domain | cut -c6-13) ]] || \
       [[ "$DELETE" == "all" ]]; then
      echo -n "Deleting servicediscovery service...$service_name"
      aws servicediscovery delete-service --id $(echo $all_services | jq -r .[$i].Id) > /tmp/route54_private
      $VERBOSE && cat /tmp/route54_private
      echo "...ok"
    fi 
  done

  num_of_namespaces=$(echo $all_namespaces | jq -r "length")
  for i in $(seq 0 $num_of_namespaces); do
    namespace_name=$(echo $all_namespaces | jq -r .[$i].Name)
    $VERBOSE && echo "Inspecting servicediscovery namespace...$namespace_name"
    if [[ "$namespace_name" = "$domain" ]] || [[ "$DELETE" == "all" ]]; then
      echo -n "Deleting servicediscovery namespace...$namespace_name"
      aws servicediscovery delete-namespace --id $(echo $all_namespaces | jq -r .[$i].Id) > /tmp/route54_private
      $VERBOSE && cat /tmp/route54_private
      echo "...ok"
    fi 
  done
done
