#!/usr/bin/env bash
set -e

# Usage: ./scripts/deploy_airflow.sh <VM_NAME> <VM_ZONE> <REMOTE_USER>
VM_NAME="${1:-airflow-server}"
VM_ZONE="${2:-us-central1-a}"
REMOTE_USER="${3:-ubuntu}"

echo "🚀 Deploying Airflow on $VM_NAME..."

# Dynamically fetch the external IP of the VM
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone "$VM_ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "Fetched external IP: $EXTERNAL_IP"

ssh -o StrictHostKeyChecking=no -i ~/.ssh/github-actions-key "$REMOTE_USER"@"$EXTERNAL_IP" <<EOF
  echo "🚀 Ensuring Docker is installed..."

  if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Installing..."
    
    sudo apt-get update -y
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Detect CPU architecture
    ARCH=\$(dpkg --print-architecture)

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Use the correct repo based on architecture
    if [ "\$ARCH" = "arm64" ]; then
      echo "✅ Detected ARM64 architecture. Using ARM64 repository."
      echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
      echo "✅ Detected AMD64 architecture. Using AMD64 repository."
      echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    sudo apt-get update -y

    # Install Docker components
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    echo "✅ Docker installed and started successfully."
  else
    echo "✅ Docker is already installed."
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Installing latest version..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
  else
    echo "✅ Docker Compose is already installed."
  fi

  echo "🔄 Adding user to Docker group..."
  sudo groupadd docker || true
  sudo usermod -aG docker \$USER
  sudo systemctl restart docker

  echo "✅ Docker setup completed."

  sudo chmod 666 /var/run/docker.sock
  echo "✅ Docker socket permissions fixed."

  mkdir -p /opt/airflow
  echo "airflow dir created."

  echo "🚀 Fixing Airflow log directory permissions..."
  sudo mkdir -p /opt/airflow/logs
  sudo chmod -R 777 /opt/airflow/logs
  sudo chown -R \$USER:\$USER /opt/airflow/logs
  echo "✅ Log directory permissions fixed."

  docker compose down || true

  docker compose up -d --remove-orphans

  echo "✅ Airflow successfully started!"
  EOF

