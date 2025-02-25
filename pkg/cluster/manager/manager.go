package manager

import (
	"fmt"
	"github.com/seaweedfs/seaweed-up/pkg/operator"
)

type Manager struct {
	User               string // username to login to the SSH server
	IdentityFile       string // path to the private key file
	UsePassword        bool   // use password instead of identity file for ssh connection
	ProxyUrl           string // proxy URL for binary download
	ComponentToDeploy  string
	Version            string
	SshPort            int
	PrepareVolumeDisks bool
	ForceRestart       bool

	skipConfig bool
	SkipEnable bool
	SkipStart  bool
	sudoPass   string
	confDir    string
	dataDir    string
}

func NewManager() *Manager {
	return &Manager{
		skipConfig: false,
		SkipEnable: false,
		SkipStart:  false,
		Version:    "",
		sudoPass:   "",
	}
}

func info(message string) {
	fmt.Println("[INFO] " + message)
}

func (m *Manager) sudo(op operator.CommandOperator, cmd string) error {
	info("[execute] " + cmd)
	if m.sudoPass == "" {
		return op.Execute(cmd)
	}
	defer fmt.Println()
	return op.Execute(fmt.Sprintf("echo '%s' | sudo -S %s", m.sudoPass, cmd))
}
