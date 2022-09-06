
package main

import (
  "bufio"
	"fmt"
  "os"
  "os/exec"
  "strings"
  "sync"
	"time"

  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/aws/session"
	nuke_aws "github.com/gruntwork-io/cloud-nuke/aws"
)

/** CLOUD-NUKE Configuration **/

// You can scan multiple regions at once, or just pass a single region for speed
var targetRegions = []string{"us-west-2"}
var excludeRegions = []string{}
// You can simultaneously target multiple resource types as well
// var resourceTypes = []string{"ec2", "vpc", "efs", "ecsserv", "ecscluster", "cloudwatch-loggroup", "eip", "nat-gateway", "elbv2"}
// var resultTypes = []string{"elbv2", "nat-gateway", "ec2", "eip", "ecsserv", "ecscluster", "cloudwatch-loggroup", "vpc", "efs"}
var resourceTypes = []string{"vpc"}
var resultTypes = resourceTypes
var excludeResourceTypes = []string{}
// excludeAfter is parsed identically to the --older-than flag
var excludeAfter = time.Now()

var aws_session, session_err = session.NewSession(&aws.Config{Region: aws.String(targetRegions[0])})

/** Interactive Input Configuration **/

var reader = bufio.NewReader(os.Stdin)
func interact(resource string) bool{
  /* Decide if to delete selected resource */
  fmt.Printf("Delete [%s] -> ", resource)
  text, _ := reader.ReadString('\n')
  // convert CRLF to LF
  text = strings.Replace(text, "\n", "", -1)

  if strings.Compare("yes", text) == 0 {
    fmt.Println("Got it! It's gone :)")
    return true
  } else {
    fmt.Println("Well fine, I'll leave it :/")
    return false
  }
}

var tag_commands = map[string]string{
  "nat-gateway":  "aws ec2 describe-nat-gateways --nat-gateway-ids %s | jq -r .NatGateways[0].Tags",
  "eip": "aws ec2 describe-addresses --filters Name=allocation-id,Values=%s | jq -r .Addresses[0].Tags",
  "vpc": "aws ec2 describe-vpcs --filters Name=vpc-id,Values=%s | jq -r .Vpcs[0].Tags",
  "efs": "aws efs describe-file-systems --file-system-id %s | jq -r .FileSystems[0].Name",
}

func checkTags(resource string, resource_class int, group string, command string) {
  if resultTypes[resource_class] == group {
    cmd := exec.Command("bash", "-c", fmt.Sprintf(command, resource))
    stdout, err := cmd.Output()
    if err != nil {
      fmt.Println(err)
    } else {
      fmt.Println(string(stdout))
    }
  }
}

func deleteResource(wg *sync.WaitGroup, list_resources nuke_aws.AwsResources, resource string) {
  defer wg.Done()
  err := list_resources.Nuke(aws_session, []string{resource})
  if err != nil {
    fmt.Println(err)
  }
}
