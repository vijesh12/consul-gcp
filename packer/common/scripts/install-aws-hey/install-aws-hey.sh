#!/bin/bash

ARCH="$( [[ "$(uname -m)" == aarch64 ]] && echo arm64 || echo amd64)"
URL="https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_${ARCH}"

set -euo pipefail

install_aws_hey() {
  echo 'installing aws (rakyll/hey repo)'
  curl -sSfl ${URL} -o ./hey
  sudo mv hey /usr/local/bin/hey
  sudo chmod a+x /usr/local/bin/hey
  if [[ ! ( $(which hey) == '/usr/local/bin/hey' ) ]];then
    echo 'failed to install aws/hey'
    exit 1
  fi
}

install_aws_hey
echo 'aws hey installed!'