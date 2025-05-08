#!/usr/bin/env bash
#
# install-gcloud.sh
# -----------------
# Installs and minimally configures the Google Cloud CLI on macOS or Linux.
#
# Flags:
#   -p <project_id>   Configure gcloud to use this project after install
#   -r <region>       Default compute/region (e.g. us-central1)
#   -z <zone>         Default compute/zone   (e.g. us-central1-a)
#   -n                Non-interactive (skip 'gcloud auth login' / 'init')
#   -h                Show help
#
set -euo pipefail

### ---------- CLI -------------

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options
  -p PROJECT_ID   Set default gcloud project after install
  -r REGION       Set default compute/region
  -z ZONE         Set default compute/zone
  -n              Non-interactive: skip browser auth / init
  -h              Show this help
EOF
  exit 1
}

NONINTERACTIVE=false
PROJECT_ID="" REGION="" ZONE=""

while getopts "p:r:z:nh" opt; do
  case "$opt" in
    p) PROJECT_ID="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    z) ZONE="$OPTARG" ;;
    n) NONINTERACTIVE=true ;;
    h|*) usage ;;
  esac
done
shift $((OPTIND-1))

### ---------- helpers ----------

info()    { printf '\033[1;32m[INFO]\033[0m %s\n' "$*"; }
warn()   { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error()  { printf '\033[1;31m[ERR ]\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || error "Required command '$1' not found."; }

have_brew() { command -v brew >/dev/null 2>&1; }
have_apt()  { command -v apt-get >/dev/null 2>&1; }
have_dnf()  { command -v dnf >/dev/null 2>&1; }
have_yum()  { command -v yum >/dev/null 2>&1; }
have_apk()  { command -v apk >/dev/null 2>&1; }
have_zypper(){ command -v zypper >/dev/null 2>&1; }

### ---------- already installed? ----------

if command -v gcloud >/dev/null 2>&1; then
  info "gcloud already installed: $(gcloud version | head -1)"
else
  ### ---------- OS detection ----------
  OS_NAME=$(uname -s)
  ARCH=$(uname -m)

  info "Detected OS: $OS_NAME  Arch: $ARCH"

  if [[ "$OS_NAME" == "Darwin" ]]; then
    # --- macOS ---
    if have_brew; then
      info "Installing via Homebrew..."
      brew update >/dev/null
      brew install --quiet google-cloud-sdk
    else
      warn "Homebrew not found. Using Google’s tarball installer."
      INSTALL_TARBALL=true
    fi
  elif [[ "$OS_NAME" == "Linux" ]]; then
    # --- Linux distros ---
    if have_apt; then
      info "Installing via apt..."
      sudo apt-get update -y
      sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
        | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | sudo tee /usr/share/keyrings/cloud.google.gpg >/dev/null
      sudo apt-get update -y
      sudo apt-get install -y google-cloud-cli
    elif have_dnf; then
      info "Installing via dnf..."
      sudo tee /etc/yum.repos.d/google-cloud-sdk.repo >/dev/null <<'REPO'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
REPO
      sudo dnf install -y google-cloud-cli
    elif have_yum; then
      info "Installing via yum..."
      sudo tee /etc/yum.repos.d/google-cloud-sdk.repo >/dev/null <<'REPO'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
REPO
      sudo yum install -y google-cloud-cli
    elif have_apk; then
      info "Installing via apk..."
      sudo apk add --no-cache python3 py3-crcmod bash curl
      curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-456.0.0-linux-x86_64.tar.gz
      tar -xzf google-cloud-cli-*-linux-*.tar.gz
      ./google-cloud-cli/install.sh --quiet
    elif have_zypper; then
      info "Installing via zypper..."
      sudo rpm --import https://packages.cloud.google.com/yum/doc/yum-key.gpg
      sudo rpm --import https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
      sudo zypper addrepo --refresh https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64 google-cloud-cli
      sudo zypper install -y google-cloud-cli
    else
      warn "No supported package manager found. Using tarball installer."
      INSTALL_TARBALL=true
    fi
  else
    error "Unsupported operating system: $OS_NAME"
  fi

  ### ---------- Tarball fallback ----------
  if [[ "${INSTALL_TARBALL:-false}" == "true" ]]; then
    need_cmd curl
    TMP_DIR=$(mktemp -d)
    pushd "$TMP_DIR" >/dev/null
    info "Fetching latest Google Cloud SDK tarball..."
    # fetch latest version json
    VERSION_JSON=$(curl -sSL https://dl.google.com/dl/cloudsdk/channels/rapid/components-2.json)
    LATEST=$(echo "$VERSION_JSON" | grep -oE '"version":\s*"[0-9.]+"' | head -1 | cut -d'"' -f4)
    [[ -z "$LATEST" ]] && error "Unable to determine latest gcloud version."
    PLATFORM="linux-x86_64"
    [[ "$OS_NAME" == "Darwin" && "$ARCH" == "arm64" ]] && PLATFORM="darwin-arm64"
    [[ "$OS_NAME" == "Darwin" && "$ARCH" != "arm64" ]] && PLATFORM="darwin-x86_64"
    TAR="google-cloud-cli-${LATEST}-${PLATFORM}.tar.gz"
    curl -# -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/${TAR}"
    tar -xzf "$TAR"
    ./google-cloud-cli/install.sh --quiet
    popd >/dev/null
    rm -rf "$TMP_DIR"
  fi
fi

### ---------- ensure in PATH / completion ----------

# gcloud installs into $HOME/google-cloud-sdk if using tarball;
# brew/apt/yum etc. put a wrapper into /usr/bin already.
if [[ ":$PATH:" != *":$HOME/google-cloud-sdk/bin:"* && -d "$HOME/google-cloud-sdk/bin" ]]; then
  echo 'export PATH="$HOME/google-cloud-sdk/bin:$PATH"' >> "$HOME/.bashrc"
  echo 'export PATH="$HOME/google-cloud-sdk/bin:$PATH"' >> "$HOME/.zshrc"
  info "Added \$HOME/google-cloud-sdk/bin to PATH in bashrc & zshrc."
fi

if [[ -f "$(command -v gcloud | sed 's|/bin/gcloud||')/path.bash.inc" ]]; then
  GCLOUD_DIR="$(command -v gcloud | sed 's|/bin/gcloud||')"
  grep -q 'path.bash.inc' "$HOME/.bashrc" 2>/dev/null || \
    echo "source '$GCLOUD_DIR/path.bash.inc'" >> "$HOME/.bashrc"
  grep -q 'completion.bash.inc' "$HOME/.bashrc" 2>/dev/null || \
    echo "source '$GCLOUD_DIR/completion.bash.inc'" >> "$HOME/.bashrc"
fi

### ---------- configure gcloud ----------

if [[ -n "$PROJECT_ID" ]]; then
  gcloud config set project "$PROJECT_ID"
  info "Set default project to $PROJECT_ID"
fi
[[ -n "$REGION" ]] && gcloud config set compute/region "$REGION" && info "Set region to $REGION"
[[ -n "$ZONE"   ]] && gcloud config set compute/zone   "$ZONE"   && info "Set zone   to $ZONE"

### ---------- auth / init ----------
gcloud components install gke-gcloud-auth-plugin
if [[ "$NONINTERACTIVE" == false ]]; then
  info "Launching browser-based auth flow..."
  gcloud auth login
  gcloud auth application-default login
  gcloud init || true
else
  info "Non-interactive mode: skipped auth / init."
fi

info "✅  gcloud installation complete (version: $(gcloud version | head -1))."
