#!/usr/bin/env bash
set -e

# Usage: ./scripts/sync_files.sh <VM_NAME> <VM_ZONE> <REMOTE_USER>
VM_NAME="airflow-server"
VM_ZONE="us-central1-a"
REMOTE_USER="ubuntu"

echo "🚀 Syncing project files to $VM_NAME..."

# Dynamically fetch the external IP of the VM
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" --zone "$VM_ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "Fetched external IP: $EXTERNAL_IP"

# SSH to prepare remote directory
ssh -o StrictHostKeyChecking=no -i ~/.ssh/github-actions-key "$REMOTE_USER"@"$EXTERNAL_IP" <<EOF
  sudo mkdir -p /opt/airflow
  sudo chown -R \$USER:\$USER /opt/airflow
  sudo chmod -R 775 /opt/airflow
  EOF

# Rsync files to the remote /opt/airflow directory
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i ~/.ssh/github-actions-key" --exclude '.git' . "$REMOTE_USER"@"$EXTERNAL_IP":/opt/airflow

echo "✅ Files synced successfully."
