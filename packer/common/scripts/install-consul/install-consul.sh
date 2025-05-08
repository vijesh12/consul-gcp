#!/bin/bash

CONSUL_VERSION="${CONSUL_VERSION:=1.15.1+ent}"
ARCH="$([[ "$(uname -m)" =~ aarch64|arm64 ]] && echo arm64 || echo amd64)"

set -euo pipefail

create_consul_user() {
    local username="${1}"
    local home_dir="${2}"

    echo "[+] Creating ${username} user | homedir: ${home_dir}"
    if ! getent passwd "${username}" >/dev/null; then
        sudo /usr/sbin/adduser \
            --system \
            --home "${home_dir}" \
            --no-create-home \
            --shell /bin/false \
            "${username}"
        sudo /usr/sbin/groupadd --force --system "${username}"
        sudo /usr/sbin/usermod --gid "${username}" "${username}"
    fi
    echo "$username soft nofile 65536" >>/etc/security/limits.conf
    echo "$username hard nofile 65536" >>/etc/security/limits.conf
}

setup_directories() {
    echo '[+] Configuring consul directories'
    # create and manage permissions on directories
    sudo mkdir --parents --mode=0755 \
        "/etc/consul.d" \
        "/etc/consul.d/tls" \
        "/var/log/consul" \
        "/opt/consul" \
        "/opt/consul/bin" \
        "/opt/consul/data" \
    ;
    sudo chown --recursive consul:consul \
        "/etc/consul.d" \
        "/etc/consul.d/tls" \
        "/var/log/consul" \
        "/opt/consul" \
        "/opt/consul/bin" \
        "/opt/consul/data" \
    ;
}

copy_tls_certs() {
    echo "[+] Transferring consul-ca and agent certs to /etc/consul.d/tls"
    sudo cp /tmp/packer_files/cfg/tls/* /etc/consul.d/tls
    sudo mv /etc/consul.d/tls/ca.pem /etc/consul.d/tls/consul-agent-ca.pem
    sudo mv /etc/consul.d/tls/ca-key.pem /etc/consul.d/tls/consul-agent-ca-key.pem
    sudo mv /etc/consul.d/tls/server.pem /etc/consul.d/tls/consul.pem
    sudo mv /etc/consul.d/tls/server-key.pem /etc/consul.d/tls/consul-key.pem

    echo "[+] Updating local certificate store with Consul CA Certificate Authority cert."
    sudo mkdir /usr/local/share/ca-certificates/consul_certs --parents
    sudo chmod 0755 /usr/local/share/ca-certificates/consul_certs
    sudo cp /etc/consul.d/tls/consul-agent-ca.pem /usr/local/share/ca-certificates/consul_certs/consul-ca.crt
    sudo chmod 0644 /usr/local/share/ca-certificates/consul_certs/consul-ca.crt
    sudo chmod 0755 /etc/consul.d/tls --recursive
}

install_consul() {
    echo "[+] Installing Consul v${CONSUL_VERSION}"
    curl \
        --silent "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${ARCH}.zip" \
        --output /tmp/consul.zip \
        --location \
        --fail

    echo "[+] Unzipping /tmp/consul.zip (${CONSUL_VERSION}) --> /tmp/consul"
    unzip \
        -o /tmp/consul.zip \
        -d /tmp 1>/dev/null

    echo "[+] Moving /tmp/consul binary --> /usr/local/bin/consul"
    sudo mv "/tmp/consul" "/usr/local/bin/consul"
    sudo chown "consul:consul" "/usr/local/bin/consul"
    sudo chmod a+x "/usr/local/bin/consul"
}

install_consul_dev_binary() {
    echo "[+] Copying dev consul binary to /usr/local/bin"
    sudo cp /tmp/packer_files/dev/consul /usr/local/bin/consul
    if sudo -E PATH="${PATH}" bash -c 'command -v consul'; then
        echo "**** Consul dev binary installed"
    else
        echo "[x] Failed to install consul"
        exit 1
    fi
}

install_systemd_file() {
    local systemd_file="${1}"
    sudo cp "/tmp/packer_files/cfg/consul/systemd/${systemd_file}" /etc/systemd/system
    sudo chmod 0644 /etc/systemd/system/"${systemd_file}"
    if [[ ("${systemd_file}" == consul.service) ]]; then
        sudo systemctl enable "${systemd_file}"
    else
        sudo systemctl disable --now "${systemd_file}"
    fi
}

install_utility_script() {
    local utility_script="${1}"
    sudo cp --verbose /tmp/packer_files/scripts/"${utility_script}" /home/ubuntu/"${utility_script}"
    sudo chmod a+x /home/ubuntu/"${utility_script}"
}

echo '***** Starting Consul install'
create_consul_user consul /opt/consul
setup_directories
install_consul
consul -autocomplete-install
complete -C /usr/local/bin/consul consul
copy_tls_certs
install_systemd_file consul.service
install_systemd_file consul-mesh-gw.service
install_systemd_file frontend.service
install_systemd_file frontend-sidecar.service
install_systemd_file backend.service
install_systemd_file backend-sidecar.service
for script in \
    upgrade-consul.sh \
    consul-tproxy-redirect.sh \
    consul-tproxy-cleanup.sh \
    prune-serf-members.sh \
    kv-transaction.sh \
    simulate-kv-load.sh \
    remove-kv-load.sh \
    retrieve-all-kvs.sh \
    redis-service-load-test.sh \
    redis-svc-deregister.sh \
    clean-ns.sh \
    manage-ns.sh \
    prepared-queries.sh \
    aws_hey.sh; do
    install_utility_script $script
done
echo '***** Consul install Complete!'
