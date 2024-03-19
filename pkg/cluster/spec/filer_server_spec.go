package spec

import (
	"bytes"
	"fmt"
	"slices"
	"strings"
)

type FilerServerSpec struct {
	Ip                 string                 `yaml:"ip"`
	PortSsh            int                    `yaml:"port.ssh" default:"22"`
	IpBind             string                 `yaml:"ip.bind,omitempty"`
	IpPublic           string                 `yaml:"ip.public,omitempty"`
	Port               int                    `yaml:"port" default:"9333"`
	PortGrpc           int                    `yaml:"port.grpc" default:"19333"`
	PortPublic         int                    `yaml:"port.public,omitempty"`
	DataCenter         string                 `yaml:"dataCenter,omitempty"`
	Rack               string                 `yaml:"rack,omitempty"`
	DefaultReplication int                    `yaml:"defaultReplication,omitempty"`
	MetricsPort        int                    `yaml:"metrics_port,omitempty"`
	Config             map[string]interface{} `yaml:"config,omitempty"`
	Arch               string                 `yaml:"arch,omitempty"`
	OS                 string                 `yaml:"os,omitempty"`
	S3                 bool                   `yaml:"s3" default:"false"`
	S3Port             int                    `yaml:"s3.port" default:"8333"`
	Webdav             bool                   `yaml:"webdav" default:"false"`
	WebdavPort         int                    `yaml:"webdav.port" default:"7333"`
}

func (f *FilerServerSpec) WriteToBuffer(masters []string, buf *bytes.Buffer) {
	spec := f
	defOptions := []string{fmt.Sprintf("master=%v", strings.Join(masters, ",")), fmt.Sprintf("port=%v", spec.Port), fmt.Sprintf("metricsPort=%v", 20000+spec.Port)}
	addOptions := make([]string, 0)
	for k, v := range spec.Config {
		addOptions = append(addOptions, fmt.Sprintf("%s=%v", k, v))
	}
	slices.Sort(addOptions)
	buf.WriteString(strings.Join(defOptions, "\n") + "\n")
	buf.WriteString(strings.Join(addOptions, "\n") + "\n")
}
