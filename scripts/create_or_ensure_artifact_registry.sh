#!/usr/bin/env bash
set -e

# --------- Configuration -----------
REGISTRY_NAME="airflow-docker-image"   # e.g. "airflow"
LOCATION="us-central1"
PROJECT_ID="primordial-veld-450618-n4"
REPO_FORMAT="docker"

echo "🔍 Checking if Artifact Registry '$REGISTRY_NAME' exists in '$LOCATION'..."

EXISTING_REPO=$(
  gcloud artifacts repositories list \
    --project="$PROJECT_ID" \
    --location="$LOCATION" \
    --filter="name~'/repositories/$REGISTRY_NAME$'" \
    --format="value(repositoryId)"
)


if [[ -z "$EXISTING_REPO" ]]; then
  echo "❌ Repository '$REGISTRY_NAME' not found. Creating it..."
  gcloud artifacts repositories create "$REGISTRY_NAME" \
    --project="$PROJECT_ID" \
    --repository-format="$REPO_FORMAT" \
    --location="$LOCATION" \
    --description="Docker repository for data-pipeline"

  echo "✅ Artifact Registry '$REGISTRY_NAME' created."
else
  echo "✅ Artifact Registry '$REGISTRY_NAME' already exists."
fi
