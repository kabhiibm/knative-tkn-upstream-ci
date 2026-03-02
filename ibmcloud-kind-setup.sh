#!/bin/bash
set -e

# -------------------------------
# Environment setup (declare defaults and export)
# -------------------------------
setup_env() {
    # ----------------------------
    # Configuration variables
    # ----------------------------
    export PCLOUD_IBM_API_KEY=${TF_VAR_powervs_api_key} # Environment variable of pod
    export PCLOUD_IBM_REGION="${PCLOUD_IBM_REGION:-eu-gb}"
    export IMAGE_NAME="${IMAGE_NAME:-centos9-stream}"
    export SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-~/.ssh/ssh-key}"
    export TIMESTAMP=$(date +%s)
    export VSI_NAME="knative-test-${TIMESTAMP}"
    #export VSI_NAME="${VSI_NAME:-knative-test}"
    export NETWORK_NAME="${VSI_NAME}-pub-net"
    export SUBNET_ID="${SUBNET_ID:-}"
    #export POLL_INTERVAL=${POLL_INTERVAL:-5}
    export VSI_IP="${VSI_IP:-}"
    export VSI_ID="${VSI_ID:-}"
    export DOCKER_CONFIG=$(cat /root/.docker/config.json)
    echo "Environment initialized."
}

install_prereqs() {
    curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
    ibmcloud --version
    ibmcloud config --check-version=false
    ibmcloud plugin install is -f power-iaas
    ibmcloud plugin install -f vpc-infrastructure
}

login_ibmcloud() {
    # ----------------------------
    # Login to IBM Cloud
    # ----------------------------
    echo "Login to IBMCLOUD and login to workspace 'rdr-knative-prow-testbed-lon06'"
    ibmcloud login --apikey "${PCLOUD_IBM_API_KEY}" -r "${PCLOUD_IBM_REGION}"
    crn=$(ibmcloud pi workspace list --json | jq  '.[] | .workspaces[] | select(.name == "rdr-knative-prow-testbed-lon06") | "\(.details.crn)"' | tr -d '"')
    ibmcloud pi workspace target $crn
    echo $crn
}

create_network() {
    # ----------------------------
    # Create network
    # ----------------------------
    echo "Create network ${NETWORK_NAME}"
    ibmcloud pi subnet create ${NETWORK_NAME} --net-type public --dns-servers "8.8.4.4,8.8.8.8"
    echo "Created subnet ${NETWORK_NAME}. Status: $?"
    SUBNET_ID=$(timeout 30 ibmcloud pi subnet ls | grep ${NETWORK_NAME} | awk '{print $1}' | head -n1)
}

create_vsi() {
    POLL_INTERVAL=5
    # ----------------------------
    # Create VSI
    # ----------------------------
    instance_output=$(ibmcloud pi instance create $VSI_NAME \
        --image $IMAGE_NAME \
        --sys-type s922 \
        --processors 1 \
        --processor-type shared \
        --key-name knative-ssh-key \
        --subnets "${SUBNET_ID}" \
        --memory 32 \
        --storage-pool-affinity \
        --storage-tier tier1 \
        --replicants 1 \
        --replicant-scheme suffix \
        --replicant-affinity-policy none \
        --json)

    VSI_ID=$(echo $instance_output | jq -r '.[0].pvmInstanceID')

    # ----------------------------
    # Wait for VSI
    # ----------------------------
    echo "Waiting for VSI to be provisioned..."
    
    #: "${VSI_ID:?VSI_ID is not set}"
    timeout 600 bash -c '
      while true; do
        status=$(
          ibmcloud pi instance get "$VSI_ID" --json 2>/dev/null \
            | jq -r '.status' 2>/dev/null \
            | tr -d '[:space:]' \
            | tr '[:lower:]' '[:upper:]'
        )
    
        if [[ "$status" == "ACTIVE" ]]; then
          echo "✅ Instance is ACTIVE"
          VSI_IP=$(ibmcloud pi instance get $VSI_ID --json | jq -r '.networks[0].externalIP') # Get VSI external IP
          break
        fi
        echo "$VSI_NAME is $status"
        sleep '"$POLL_INTERVAL"'
      done
    '
    rc=$?
    
    if [[ $rc -eq 0 ]]; then
      echo "Done."
    #elif [[ $rc -eq 124 ]]; then
    #  echo "⛔ Timed out after 600s waiting for ACTIVE."
    #  exit 124
    else
      echo "⚠️ Command failed with exit code $rc."
      exit "$rc"
    fi
}


create_kind_cluster() {
    # ----------------------------
    # Test SSH
    # ----------------------------
    #chmod 600 "${SSH_PRIVATE_KEY}"

    #ssh -o StrictHostKeyChecking=no -i "${SSH_PRIVATE_KEY}" root@"$VSI_IP" "echo 'SSH OK'"

    # ----------------------------
    # Install Docker & Kind inside VSI
    # ----------------------------
    echo "Installing Docker and Kind on VSI..."
    DOCKER_CONFIG=$(cat /root/.docker/config.json) \
    ssh -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY" root@"$VSI_IP" <<'EOF'
    set -e

    # Install Docker
    # Add Docker's official GPG key:
    sudo dnf update -y
    sudo dnf install ca-certificates curl

    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin git make -y

    # Start docker service
    systemctl enable docker
    systemctl restart docker

    # Install Kind
    git clone https://github.com/kubernetes-sigs/kind.git
    cd kind
    make build
    cp /root/kind/bin/kind /usr/local/bin/kind
    chmod +x /usr/local/bin/kind
    cd 

    # Install kubectl
    K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/ppc64le/kubectl"
    sudo chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    kubectl version --client

    # KinD cluster config
    KIND_IMAGE='quay.io/powercloud/kind-node'
    KIND_CLUSTER_NAME='mkpod'
    #DOCKER_CONFIG='/root/.docker/config.json'

    #cat <<CONFIG > /root/config.json
    #{
    #  "auths": {
    #    "na.artifactory.swg-devops.com": {
    #      "auth": "dmFsZW4ubWFzY2FyZW5oYXNAaWJtLmNvbTpjbVZtZEd0dU9qQXhPakUzTXpNeU1EWTFOVGM2WkdGNWVWSldURUZaVmtoclpVNTZRVTF3ZGtsbFZGbFRNbXhv"
    #    },
    #    "quay.io": {
    #      "auth": "b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfMGIzN2ZjNGY3Y2Q5NDQxYmEzMzA2Y2Q2NjA1ZmViNmY6QVJROVpTUE9RWTlaOU5FVUNURTk2UDNRUFNOUkEwMzNISTJWNkM1NUwxQU9SSlJDTEVTTVdTQjBKTEpXR0owQQ=="
    #    },
    #    "icr.io": {
    #      "auth": "aWFtYXBpa2V5OjRQOU9zdG81Z3RyalFDeHJPalhVNUdMRmdKWlJpS1RIVGhZUFYySEpvYTBC"
    #    }
    #  }
    #}
    #CONFIG

    echo ${DOCKER_CONFIG} > /root/config.json

    # Create kind-config.yaml
    cat <<'YAML' > /root/kind-config.yaml
    apiVersion: kind.x-k8s.io/v1alpha4
    kind: Cluster
    nodes:
    - extraMounts:
      - containerPath: /var/lib/kubelet/config.json
        hostPath: /root/config.json
      image: ${KIND_IMAGE}:${K8S_VERSION}
      role: control-plane
      kubeadmConfigPatches:
      - |
        kind: ClusterConfiguration
        apiServer:
          certSANs:
          - "${VSI_IP}"
          - "127.0.0.1"
          - "0.0.0.0"
          - "localhost"
      extraPortMappings:
      - containerPort: 6443
        hostPort: 6443
        listenAddress: "0.0.0.0"
        protocol: TCP
    - extraMounts:
      - containerPath: /var/lib/kubelet/config.json
        hostPath: /root/config.json
      image: ${KIND_IMAGE}:${K8S_VERSION}
      role: worker
    YAML

    # Create cluster
    kind create cluster --name ${KIND_CLUSTER_NAME} --config /root/kind-config.yaml

    kubectl get nodes
    EOF

    mkdir -p /root/.kube
    scp -o StrictHostKeyChecking=no -i "$SSH_PRIVATE_KEY" root@"$VSI_IP":/root/.kube/config /root/.kube/config

    # Replace internal IP with VSI_IP in kubeconfig
    sed -i "s#server: https://.*:6443#server: https://${VSI_IP}:6443#g" /root/.kube/config

    echo "✅ VSI ready with Docker & KinD installed."
}

delete_cluster() {
    ibmcloud pi instance delete ${VSI_ID} --delete-data-volumes=True
    ibmcloud pi snet delete ${SUBNET_ID}
}


setup_env
install_prereqs
login_ibmcloud
create_network
create_vsi
create_kind_cluster