
package main

import (
	"fmt"
  "sync"

	nuke_aws "github.com/gruntwork-io/cloud-nuke/aws"
)

func main() {
  fmt.Println("Are you ready to nuke some AWS Resources?!")
  fmt.Println("---------------------")

  queryResources()
}

func queryResources() {
  var wg sync.WaitGroup

	// NewQuery is a convenience method for configuring parameters you want to pass to your resource search
	query, err := nuke_aws.NewQuery(
		targetRegions,
		excludeRegions,
		resourceTypes,
		excludeResourceTypes,
		excludeAfter,
	)
	if err != nil {
		fmt.Println(err)
	}

	// InspectResources still returns *AwsAccountResources, but this struct has been extended with several
	// convenience methods for quickly determining if resources exist in a given region
	accountResources, err := nuke_aws.InspectResources(query)
	if err != nil {
		fmt.Println(err)
	}
  for region, all_resources := range accountResources.Resources {
    // fmt.Printf("Region: [%s]\n", region)
    for _, list_resources := range all_resources.Resources {
      // fmt.Printf("AWS Resource Class: [%s]\n", resourceTypes[class_name])
      for _, resource := range list_resources.ResourceIdentifiers() {
        fmt.Println("\n\n\n\n\n")
        checkTags(resource, getServiceType(resource), tag_commands[getServiceType(resource)])
        if interact(fmt.Sprintf("%s : %s : %s", region, getServiceType(resource), resource)) {
          wg.Add(1)
          go deleteResource(&wg, list_resources, resource)
        }
      }
    }
  }
  fmt.Println("Waiting for background processes to complete...")
  wg.Wait()
}
