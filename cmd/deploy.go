package cmd

import (
	"context"
	_ "embed"
	"fmt"
	"github.com/muesli/coral"
	"github.com/pkg/errors"
	"github.com/seaweedfs/seaweed-up/pkg/cluster/manager"
	"github.com/seaweedfs/seaweed-up/pkg/cluster/spec"
	"github.com/seaweedfs/seaweed-up/pkg/config"
	"github.com/seaweedfs/seaweed-up/pkg/utils"
	"gopkg.in/yaml.v3"
	"net"
	"os"
	"path"
)

func DeployCommand() *coral.Command {

	m := manager.NewManager()
	m.IdentityFile = path.Join(utils.UserHome(), ".ssh", "id_rsa")

	var cmd = &coral.Command{
		Use:          "deploy",
		Short:        "deploy a configuration file",
		Long:         "deploy a configuration file",
		SilenceUsage: true,
	}
	var fileName string
	cmd.Flags().StringVarP(&fileName, "file", "f", os.Args[0]+".yaml", "configuration file")
	cmd.Flags().StringVarP(&m.User, "user", "u", utils.CurrentUser(), "The user name to login via SSH. The user must has root (or sudo) privilege.")
	cmd.Flags().IntVarP(&m.SshPort, "port", "p", 22, "The port to SSH.")
	cmd.Flags().StringVarP(&m.IdentityFile, "identity_file", "i", m.IdentityFile, "The path of the SSH identity file. If specified, public key authentication will be used.")
	cmd.Flags().StringVarP(&m.Version, "version", "v", "", "The SeaweedFS version")
	cmd.Flags().StringVarP(&m.ComponentToDeploy, "component", "c", "", "[master|volume|filer|envoy] only install one component")
	cmd.Flags().BoolVarP(&m.PrepareVolumeDisks, "mountDisks", "", false, "auto mount disks on volume server if unmounted")
	cmd.Flags().BoolVarP(&m.ForceRestart, "restart", "", false, "force to restart the service")
	cmd.Flags().BoolVarP(&m.SkipEnable, "skipEnable", "E", false, "skip to enable the service")
	cmd.Flags().BoolVarP(&m.SkipStart, "skipStart", "S", false, "skip to start the service")
	cmd.Flags().StringVarP(&m.ProxyUrl, "proxy", "x", "", "proxy for curl in format PROTO://PROXY (example: http://someproxy.com:8080/)")

	cmd.RunE = func(command *coral.Command, args []string) error {

		if m.Version == "" {
			latest, err := config.GitHubLatestRelease(context.Background(), "0", "seaweedfs", "seaweedfs")
			if err != nil {
				return errors.Wrapf(err, "unable to get latest version number, define a version manually with the --version flag")
			}
			m.Version = latest.Version
		}

		spec := &spec.Specification{}
		data, readErr := os.ReadFile(fileName)
		if readErr != nil {
			return fmt.Errorf("read %s: %v", fileName, readErr)
		}
		if unmarshalErr := yaml.Unmarshal(data, spec); unmarshalErr != nil {
			return fmt.Errorf("unmarshal %s: %v", fileName, unmarshalErr)
		}

		localIP := "127.0.0.1"
		if netInterfaces, err := net.Interfaces(); err == nil {
			for i := 0; i < len(netInterfaces); i++ {
				if netInterfaces[i].HardwareAddr == nil || netInterfaces[i].HardwareAddr.String() == "ee:ee:ee:ee:ee:ee" {
					continue
				} else {
					if (netInterfaces[i].Flags & net.FlagUp) != 0 {
						addrs, _ := netInterfaces[i].Addrs()
						for _, addr := range addrs {
							if ip, ok := addr.(*net.IPNet); ok &&
								ip.IP.To4() != nil &&
								ip.IP.IsPrivate() &&
								!ip.IP.IsLoopback() {
								localIP = ip.IP.String()
							}
						}
					}
				}
			}
		}
		for _, v := range spec.EnvoyServers {
			if v.Ip == "" {
				v.Ip = localIP
			}
		}
		for i, v := range spec.MasterServers {
			if v.Ip == "" {
				v.Ip = localIP
			}
			if v.Port == 0 {
				v.Port = 9333 + i
			}
		}
		for i, v := range spec.VolumeServers {
			if v.Ip == "" {
				v.Ip = localIP
			}
			if v.Port == 0 {
				v.Port = 8080 + i
			}
		}
		for i, v := range spec.FilerServers {
			if v.Ip == "" {
				v.Ip = localIP
			}
			if v.Port == 0 {
				v.Port = 8888 + i
			}
		}
		return m.DeployCluster(spec)
	}

	return cmd
}
