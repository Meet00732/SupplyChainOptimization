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

ssh -o StrictHostKeyChecking=no -i ~/.ssh/github-actions-key "$REMOTE_USER@$EXTERNAL_IP" <<EOF
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
    echo "❌ Docker Compose not found. Installing..."
    sudo apt-get install -y docker-compose-plugin
  else
    echo "✅ Docker Compose is already installed."
  fi

  echo "🔄 Adding user to Docker group..."
  sudo groupadd docker || true
  sudo usermod -aG docker \$USER
  sudo systemctl restart docker

  echo "✅ Docker setup completed."

  # Fix Docker socket permissions
  sudo chown root:docker /var/run/docker.sock
  echo "✅ Docker socket permissions fixed."

  echo "🚀 Ensuring Docker service is running..."
  sudo systemctl is-active --quiet docker || sudo systemctl restart docker

  mkdir -p /opt/airflow
  echo "airflow dir created."

  echo "🚀 Fixing Airflow log directory permissions..."
  sudo mkdir -p /opt/airflow/logs
  sudo chmod -R 777 /opt/airflow/logs
  sudo chown -R \$USER:\$USER /opt/airflow/logs
  echo "✅ Log directory permissions fixed."

  # Remove /opt/airflow/gcp-key.json if it exists as a directory
  if [ -d /opt/airflow/gcp-key.json ]; then
    echo "⚠️ Found directory at /opt/airflow/gcp-key.json. Removing it..."
    sudo rm -rf /opt/airflow/gcp-key.json
  fi

  # Create the GCP Key file from the secret
  echo "🚀 Creating GCP Key File..."
  echo "$GCP_SERVICE_ACCOUNT_KEY" | jq . > /opt/airflow/gcp-key.json
  chmod 644 /opt/airflow/gcp-key.json
  sudo chown \$USER:docker /opt/airflow/gcp-key.json
  echo "✅ GCP Key File Created."

  cd /opt/airflow

  echo "🚀 Pulling the latest image from Artifact Registry..."
  gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
  docker compose pull || true

  echo "🚀 Stopping any running containers..."
  docker compose down || true

  # Remove postgres volume if you want to reset the DB (warning: this clears data)
  docker volume rm airflow_postgres-db-volume || true

  echo "🚀 Starting Airflow using Docker Compose..."
  docker compose up -d --remove-orphans

  echo "✅ Airflow successfully started!"
EOF
