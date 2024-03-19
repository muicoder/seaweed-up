#!/bin/sh
set -e
hostIP=$(hostname -I | awk '{print $1}' 2>/dev/null || hostname)
info() {
  echo "[INFO]($hostIP) ->" "$@"
}

fatal() {
  echo "[ERROR]($hostIP) ->" "$@"
  exit 1
}

verify_system() {
  if ! [ -d /run/systemd ]; then
    fatal "Can not find systemd to use as a process supervisor for seaweed_${PRODUCT}"
  fi
}

setup_sudo() {
  SUDO=sudo
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=
  else
    if [ -n "$SUDO_PASS" ]; then
      echo "$SUDO_PASS" | sudo -S true
      echo ""
    fi
  fi
}

setup_env() {
  setup_sudo

  COMPONENT_INSTANCE={{.ComponentInstance}}
  COMPONENT={{.Component}}
  CONFIG_DIR={{.ConfigDir}}
  DATA_DIR={{.DataDir}}

  SEAWEED_COMPONENT_INSTANCE_DATA_DIR=${DATA_DIR}/${COMPONENT_INSTANCE}
  SEAWEED_COMPONENT_INSTANCE_CONFIG_DIR=${CONFIG_DIR}/${COMPONENT_INSTANCE}.d
  SEAWEED_COMPONENT_INSTANCE_SERVICE_FILE=/etc/systemd/system/seaweed_${COMPONENT_INSTANCE}.service

  BIN_DIR=/usr/local/bin
  BINARY=weed

  PRE_INSTALL_HASHES=$(get_installed_hashes)

  TMP_DIR={{.TmpDir}}
  SKIP_ENABLE={{.SkipEnable}}
  SKIP_START={{.SkipStart}}
  FORCE_RESTART={{.ForceRestart}}
  SEAWEED_VERSION={{.Version}}

  cd $TMP_DIR
}

# --- set arch and suffix, fatal if architecture not supported ---
setup_verify_arch() {
  if [ -z "$ARCH" ]; then
    ARCH=$(uname -m)
  fi
  case $ARCH in
  amd64)
    FULL_SUFIX="_full"
    SUFFIX=amd64
    ;;
  x86_64)
    SUFFIX=amd64
    ;;
  arm64)
    SUFFIX=arm64
    ;;
  aarch64)
    SUFFIX=arm64
    ;;
  arm*)
    SUFFIX=arm
    ;;
  *)
    fatal "Unsupported architecture $ARCH"
    ;;
  esac
}

# --- get hashes of the current seaweed bin and service files
get_installed_hashes() {
  setup_sudo
  $SUDO sha256sum ${BIN_DIR}/${BINARY} ${CONFIG_DIR}/${COMPONENT_INSTANCE}.options ${SEAWEED_COMPONENT_INSTANCE_SERVICE_FILE} 2>/dev/null || true
}

has_yum() {
  [ -n "$(command -v yum)" ]
}

has_apt_get() {
  [ -n "$(command -v apt-get)" ]
}

install_dependencies() {
  if [ ! -x "${TMP_DIR}/seaweed_${COMPONENT_INSTANCE}" ]; then
    if ! [ -x "$(command -v tar)" ] || ! [ -x "$(command -v curl)" ]; then
      if has_apt_get; then
        $SUDO apt-get install -y curl tar
      elif has_yum; then
        $SUDO yum install -y curl tar
      else
        fatal "Could not find apt-get or yum. Cannot install dependencies on this OS"
      fi
    fi
  fi
}

download_and_install() {
  if [ -x "${BIN_DIR}/${BINARY}" ] && [ "$(${BIN_DIR}/${BINARY} version | cut -d' ' -f3)" = "${SEAWEED_VERSION}" ]; then
    info "Seaweed binary already installed for ${COMPONENT_INSTANCE} => ${BIN_DIR}/${BINARY}"
  else
    OS="linux"
    LARGE_SUFIX="_large_disk"
    assetFileName="${OS}_${SUFFIX}${FULL_SUFIX}${LARGE_SUFIX}.tar.gz"
    info "Downloading ${SEAWEED_VERSION} ${assetFileName}"
    curl {{.ProxyConfig}} -o "$TMP_DIR/seaweed_${SEAWEED_VERSION}_${assetFileName}" -sfL "https://github.com/seaweedfs/seaweedfs/releases/download/${SEAWEED_VERSION}/${assetFileName}"

    info "Downloading ${SEAWEED_VERSION} ${assetFileName} md5"
    curl {{.ProxyConfig}} -o "$TMP_DIR/seaweed_${SEAWEED_VERSION}_${assetFileName}.md5" -sfL "https://github.com/seaweedfs/seaweedfs/releases/download/${SEAWEED_VERSION}/${assetFileName}.md5"
    info "Verifying downloaded ${SEAWEED_VERSION} ${assetFileName}"
    md5Value=$(cat $TMP_DIR/seaweed_${SEAWEED_VERSION}_${assetFileName}.md5)
    echo "${md5Value}  seaweed_${SEAWEED_VERSION}_${assetFileName}" | md5sum -c

    info "Unpacking ${SEAWEED_VERSION} ${assetFileName}"
    $SUDO tar xvf "$TMP_DIR/seaweed_${SEAWEED_VERSION}_${assetFileName}" --directory $BIN_DIR
  fi
}

create_user_and_config() {
  $SUDO mkdir --parents ${SEAWEED_COMPONENT_INSTANCE_DATA_DIR}
  $SUDO mkdir --parents ${CONFIG_DIR}
  ${BIN_DIR}/${BINARY} scaffold -config 2>&1 | grep Example: | awk -F= '{print $NF}' | sed 's~\[~~g;s~\]~~g;s~|~\n~g' | while read -r cc; do if ! [ -s "$CONFIG_DIR/$cc.toml" ]; then ${BIN_DIR}/${BINARY} scaffold -config "$cc" >"$CONFIG_DIR/$cc.toml"; fi; done
  if ! [ -s $CONFIG_DIR/SeaweedFS.crt ]; then
    echo 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 | base64 -d | tar -xz -C$CONFIG_DIR
  fi
  case $COMPONENT in
  filer)
    if ! [ -s $SEAWEED_COMPONENT_INSTANCE_DATA_DIR/filer.s3weed ]; then
      echo ewogICJhY2NvdW50cyI6IFsKICAgIHsKICAgICAgImRpc3BsYXlOYW1lIjogIlNlYXdlZWRGUyIsCiAgICAgICJlbWFpbEFkZHJlc3MiOiAid2VlZEBzZWF3ZWVkZnMudmlwIiwKICAgICAgImlkIjogIndlZWQiCiAgICB9CiAgXSwKICAiaWRlbnRpdGllcyI6IFsKICAgIHsKICAgICAgImFjY291bnQiOiB7CiAgICAgICAgImlkIjogIndlZWQiCiAgICAgIH0sCiAgICAgICJhY3Rpb25zIjogWwogICAgICAgICJBZG1pbiIKICAgICAgXSwKICAgICAgImNyZWRlbnRpYWxzIjogWwogICAgICAgIHsKICAgICAgICAgICJhY2Nlc3NLZXkiOiAiV0VFRGMyVmhkMlZsWkdaendlZWQiLAogICAgICAgICAgInNlY3JldEtleSI6ICJXRUVEYzJWaGQyVmxaR1p6YzJWaGQyVmxaR1p6TFc5d1pYSmhkRzl5IgogICAgICAgIH0KICAgICAgXSwKICAgICAgIm5hbWUiOiAid2VlZCIKICAgIH0KICBdCn0K | base64 -d >$SEAWEED_COMPONENT_INSTANCE_DATA_DIR/filer.s3weed
    fi
    ;;
  esac
    if [ "$(ls -A ${TMP_DIR}/config/)" ]; then
      if ! diff ${TMP_DIR}/config/${COMPONENT}.options ${CONFIG_DIR}/${COMPONENT_INSTANCE}.options 2>/dev/null; then
        $SUDO cp ${TMP_DIR}/config/${COMPONENT}.options ${CONFIG_DIR}/${COMPONENT_INSTANCE}.options
        info "Applying configuration => ${CONFIG_DIR}/${COMPONENT_INSTANCE}.options"
        echo W2NsdXN0ZXJdCmRlZmF1bHQ9IndlZWQiCgpbY2x1c3Rlci53ZWVkXQptYXN0ZXI9IiRtSVBzIgoK | base64 -d | mIPs=$(grep '[sre][sre]=[0-9]*' ${CONFIG_DIR}/${COMPONENT_INSTANCE}.options | awk -F= '{print $NF}') envsubst >$CONFIG_DIR/shell.toml
      fi
    fi
}

# --- write systemd service file ---
create_systemd_service_file() {
  $SUDO tee ${COMPONENT_INSTANCE} >/dev/null <<EOF
[Unit]
Description=Seaweed(${COMPONENT_INSTANCE})
Documentation=https://github.com/seaweedfs/seaweedfs/wiki
Wants=network-online.target
After=network-online.target

[Service]
WorkingDirectory=${SEAWEED_COMPONENT_INSTANCE_DATA_DIR}
ExecStart=${BIN_DIR}/${BINARY} ${COMPONENT} -options=${CONFIG_DIR}/${COMPONENT_INSTANCE}.options
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF
  if ! diff ${COMPONENT_INSTANCE} ${SEAWEED_COMPONENT_INSTANCE_SERVICE_FILE} 2>/dev/null; then
    $SUDO cp ${COMPONENT_INSTANCE} ${SEAWEED_COMPONENT_INSTANCE_SERVICE_FILE}
    info "Applying systemd service => ${SEAWEED_COMPONENT_INSTANCE_SERVICE_FILE}"
    $SUDO systemctl daemon-reload >/dev/null
  fi
}

# --- startup systemd service ---
systemd_enable_and_start() {
  [ "${SKIP_ENABLE}" = true ] && return
  if [ "$(systemctl is-enabled seaweed_${COMPONENT_INSTANCE})" != enabled ]; then
    info "Enabling systemd service => seaweed_$COMPONENT_INSTANCE"
    $SUDO systemctl enable ${SEAWEED_COMPONENT_INSTANCE_SERVICE_FILE} >/dev/null
  fi

  [ "${SKIP_START}" = true ] && return

  if [ "$(systemctl is-active seaweed_${COMPONENT_INSTANCE})" != active ]; then
    info "Starting systemd service => seaweed_$COMPONENT_INSTANCE"
    $SUDO systemctl start seaweed_${COMPONENT_INSTANCE}
    return
  fi
  if [ "${FORCE_RESTART}" != true ]; then
    if [ "${PRE_INSTALL_HASHES}" = "$(get_installed_hashes)" ]; then
      info "No change detected so skipping systemd service => seaweed_${COMPONENT_INSTANCE}"
      return
    fi
  fi

  info "Restarting systemd service => seaweed_$COMPONENT_INSTANCE"
  $SUDO systemctl restart seaweed_${COMPONENT_INSTANCE}

  return 0
}

setup_env
setup_verify_arch
verify_system
install_dependencies
create_user_and_config
download_and_install
create_systemd_service_file
systemd_enable_and_start
