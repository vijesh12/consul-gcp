#!/bin/bash


set -e

readonly HASHICORP_RELEASES_API=https://api.releases.hashicorp.com
readonly SCRIPT_NAME="$(basename "$0")"


function now { date '+%d/%m/%Y %H:%M:%S'; }
function print_usage {
  cat <<-EOF
#####################
Install/Upgrade Consul/Envoy
#####################

  Requires:    curl, jq, unzip
  Platform(s): linux | macosx

Usage:
    Full:
      $(basename "$0") [--version <1.16.2>] [--enterprise]

Parameters:

  -version|--version)
    Set installation at specific version
    Default: latest

Flags:

  -e | --enterprise)
    Install enterprise version of binary.
    Default: unset|null|false

  -o | --oss)
    Install OSS version of binary. (DEFAULT)

EOF
}

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}


function get_latest {
  local product latest_version
  product="$(tr '[:upper:]' '[:lower:]' <<<"$1")"
  latest_version="$( curl -sSlf "${HASHICORP_RELEASES_API}"/v1/releases/"${product}"/latest | jq -r .version || {
    log_error "$product: failed to retrieve latest version"
  } )"
  echo "$latest_version"
}

function consul_envoy_supported {
    local version_string="$1"
    if [ "$version_string" = "latest" ]; then
      version_string="$(get_latest consul)"
    fi
    # Remove the leading "v" if present
    version_string="${version_string#v}"
    # Remove the "+ent" if present
    version_string="${version_string%%+ent}"

    # Extract the major version part (e.g., "1.14" from "1.14.4")
    major_version=$(echo "$version_string" | cut -d'.' -f1,2)
    # Define the string map (associative array)
    declare -A consul_versions
    # Populate the string map with consul versions and their compatible Envoy versions
    consul_versions["1.18.x"]="1.28.2, 1.27.4, 1.26.8, 1.25.11"
    consul_versions["1.17.x"]="1.27.4, 1.26.8, 1.25.11, 1.24.12"
    consul_versions["1.16.x"]="1.26.8, 1.25.11, 1.24.12, 1.23.12"
    consul_versions["1.15.x"]="1.28.2, 1.27.4, 1.26.8, 1.25.11, 1.24.12, 1.23.12, 1.22.11"

  if [[ -n "${consul_versions[$major_version.x]}" ]]; then
    compatible_envoy_versions="${consul_versions[$major_version.x]}"
    latest_envoy_version="$(echo "$compatible_envoy_versions" | tr -d ' ' | tr ',' '\n' | sort -V | tail -n1)"
    echo "$latest_envoy_version"
  else
    echo ""
  fi
}

function download_and_install_consul {
  local -r version="$1"
  local download_url cpu_arch

  cpu_arch="$( [[ "$(uname -m)" =~ aarch64|arm64 ]] && echo arm64 || echo amd64)"
  download_url="https://releases.hashicorp.com/consul/${version}/consul_${version}_linux_${cpu_arch}.zip"

  curl -sSlf "$download_url" -o /tmp/consul.zip
    
  log_info "unzipping /tmp/consul.zip => /tmp/consul"
  unzip -o /tmp/consul.zip -d /tmp >/dev/null 2>&1 || true
  
  if [[ -f /usr/local/bin/consul ]]; then
    log_info "removing previous consul binary at /usr/local/bin/consul"
    sudo rm -rf /usr/local/bin/consul; 
  fi
  
  log_info "moving consul binary to /usr/local/bin/consul"
  sudo mv /tmp/consul /usr/local/bin/consul
  sudo chown consul:consul /usr/local/bin/consul
  sudo chmod a+x /usr/local/bin/consul
}

function download_and_install_envoy {
  local -r version="$1"
  local cpu_arch

  cpu_arch="$( [[ "$(uname -m)" =~ aarch64|arm64 ]] && echo arm64 || echo amd64)"
  
  if [[ -f /usr/local/bin/envoy ]]; then
    log_info "removing previous envoy binary at /usr/local/bin/envoy"
    sudo rm -rf /usr/local/bin/envoy; 
  fi
  
  log_info "downloading envoy v$version"
  wget "https://archive.tetratelabs.io/envoy/download/v${version}/envoy-v${version}-linux-${cpu_arch}.tar.xz" &>/dev/null
  
  log_info "installing envoy v${version} to /usr/local/bin/envoy"
  sudo tar -xf "envoy-v${version}-linux-${cpu_arch}.tar.xz"
  sudo chmod +x "envoy-v${version}-linux-${cpu_arch}/bin/envoy"
  sudo mv "envoy-v${version}-linux-${cpu_arch}/bin/envoy" "/usr/bin/envoy"
  
  log_info "cleaning up..."
  sudo rm -rf "envoy-v${version}-linux-${cpu_arch}.tar.xz" "envoy-v${version}-linux-${cpu_arch}"
}

function upgrade_consul {
  local consul_version envoy_version
  local ent oss

  while [[ $# -gt 0 ]]; do
    local key="$1"
    case "$key" in
      -v|--version)
        consul_version="$2"
        shift
        ;;
      -e|--enterprise)
        ent=1
        oss=0
        ;;
      -o|--oss)
        oss=1
        ent=0
        ;;
      -h|--help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac
    shift
  done

  assert_not_empty "--version" "$consul_version"
  if [ "$consul_version" = "latest" ]; then
    consul_version="$(get_latest consul)"
  fi
  [ "$ent" = 1 ] && consul_version="$consul_version+ent";
  envoy_version="$(consul_envoy_supported "$consul_version")"

  if [ -z "$envoy_version" ]; then
    log_error "failed to find corresponding envoy version!"
    exit 1
  fi

  echo ""
  echo "$(now): [install/upgrade] consul + envoy"
  echo "------------------------------------"
  echo "versioning: "
  echo "      consul => v${consul_version}"
  echo "      envoy  => v${envoy_version}"
  echo "------------------------------------"
  echo ""
  read -r -p "press enter to accept or ctrl+c to exit: "
  
  download_and_install_consul "$consul_version"
  command -v consul >/dev/null 2>&1 || {
    log_error "$(now) consul installation failed! exiting..."
    exit 1
  }
  log_info "consul install/upgrade completed successfully!"


  download_and_install_envoy "$envoy_version"
  command -v envoy >/dev/null 2>&1 || {
      log_error "$(now) envoy installation failed! exiting..."
      exit 1
  }
  log_info "envoy install/upgrade completed successfully!"
}

upgrade_consul "$@"
log_info "consul + envoy installation and upgrade complete!"
echo "consul $(consul version | head -n1 | awk '{print $2}') | envoy v$(envoy --version | awk '{printf $3}' | cut -d'/' -f2)"