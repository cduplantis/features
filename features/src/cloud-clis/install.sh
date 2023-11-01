#!/usr/bin/env bash
set -ex

# Clean up
rm -rf /var/lib/apt/lists/*

INSTALL_AZCLI="${INSTALLAZURE:-true}"
INSTALL_AWSCLI="${INSTALLAWS:-true}"
INSTALL_GCLOUDCLI="${INSTALLGCLOUD:-true}"

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" > /etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

architecture="$(uname -m)"
if [ "${architecture}" != "amd64" ] && [ "${architecture}" != "x86_64" ] && [ "${architecture}" != "arm64" ] && [ "${architecture}" != "aarch64" ]; then
    echo "(!) Architecture $architecture unsupported"
    exit 1
fi

updaterc() {
    if [ "${UPDATE_RC}" = "true" ]; then
        echo "Updating /etc/bash.bashrc and /etc/zsh/zshrc..."
        if [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/bash.bashrc
        fi
        if [ -f "/etc/zsh/zshrc" ] && [[ "$(cat /etc/zsh/zshrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/zsh/zshrc
        fi
    fi
}

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

# Source /etc/os-release to get OS info
. /etc/os-release

# Install dependencies
check_packages build-essential curl unzip gpg ca-certificates tar gettext libssl-dev zlib1g-dev libcurl?-openssl-dev libexpat1-dev

echo "Activating feature 'cloud-clis'"

if [ "${INSTALL_AZCLI}" = "true" ]; then
    echo "Activating 'cloud-clis:azure cli tool'"
    # Install AZ CLI
    echo "curl is at $(which curl)"
    curl -sL https://aka.ms/InstallAzureCLIDeb -o "azinstall.sh"
    chmod +x azinstall.sh
    ./azinstall.sh
    rm ./azinstall.sh
    echo "Completed activating 'cloud-clis:azure cli tool'"
fi

if [ "${INSTALL_AWSCLI}" = "true" ]; then
    echo "Activating 'cloud-clis:aws cli tool'"
    # Install aws CLI
    curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -f awscliv2.zip
fi

if [ "${INSTALL_GCLOUDCLI}" = "true" ]; then
    echo "Activating 'cloud-clis:gcloud cli tool'"
    # Install gcloud CLI
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    apt-get update
    apt-get install google-cloud-sdk -y
    echo "Completed activating 'cloud-clis:gcloud cli tool'"
fi

echo "Finished activating feature 'cloud-clis'"
exit 0