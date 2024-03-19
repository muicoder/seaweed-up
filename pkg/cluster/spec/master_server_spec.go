package spec

import (
	"bytes"
	"fmt"
	"slices"
	"strings"
)

type MasterServerSpec struct {
	Ip                 string                 `yaml:"ip"`
	PortSsh            int                    `yaml:"port.ssh" default:"22"`
	IpBind             string                 `yaml:"ip.bind,omitempty"`
	Port               int                    `yaml:"port" default:"9333"`
	PortGrpc           int                    `yaml:"port.grpc" default:"19333"`
	VolumeSizeLimitMB  int                    `yaml:"volumeSizeLimitMB" default:"5000"`
	DefaultReplication string                 `yaml:"defaultReplication,omitempty"`
	MetricsPort        int                    `yaml:"metrics_port,omitempty"`
	Config             map[string]interface{} `yaml:"config,omitempty"`
	Arch               string                 `yaml:"arch,omitempty"`
	OS                 string                 `yaml:"os,omitempty"`
}

func (masterSpec *MasterServerSpec) WriteToBuffer(masters []string, buf *bytes.Buffer) {
	spec := masterSpec
	defOptions := []string{fmt.Sprintf("peers=%v", strings.Join(masters, ",")), fmt.Sprintf("port=%v", spec.Port), fmt.Sprintf("metricsPort=%v", 20000+spec.Port)}
	addOptions := make([]string, 0)
	for k, v := range spec.Config {
		addOptions = append(addOptions, fmt.Sprintf("%s=%v", k, v))
	}
	slices.Sort(addOptions)
	buf.WriteString(strings.Join(defOptions, "\n") + "\n")
	buf.WriteString(strings.Join(addOptions, "\n") + "\n")
}
