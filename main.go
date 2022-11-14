package main

import (
	"fmt"
	"os"

	"github.com/seaweedfs/seaweed-up/cmd"
	"github.com/seaweedfs/seaweed-up/pkg/operator"
)

func main() {
	if err := cmd.Execute(); err != nil {

		switch err.(type) {
		case *operator.TargetConnectError:
			fmt.Printf(targetConnectErrorMessage, err)
		case *operator.SshAgentError:
			fmt.Printf(sshAgentErrorMessage, err)
		default:
			fmt.Println(err)
		}

		os.Exit(1)
	}
}

const sshAgentErrorMessage = `
There was an issue finding a private key. 
This could happen when seaweed-up can not reach an authentication agent or when no private key is loaded.

Reason: %s

How to fix this?

- check if an authentication agent is running and add a private key, e.g. 'ssh-add ~/.ssh/id_rsa'
- or add the '--ssh-target-key' flag to use a specific key, e.g. '--ssh-target-key ~/.ssh/id_rsa'

`

const targetConnectErrorMessage = `
There was an issue connecting to your target host. 
This could happen when seaweed-up can not reach the target host or when the private key authentication is invalid.

Reason: %s

How to fix this?

- check if the target host is reachable and an SSH server is running
- check if the user and the private key are valid

`
