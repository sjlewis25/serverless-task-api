#!/bin/bash
set -e

cd "$(dirname "$0")/../infrastructure"

CURRENT_ENV=$(terraform workspace show)

echo "WARNING: This will DESTROY all infrastructure in environment: $CURRENT_ENV"
read -p "Type the environment name to confirm: " confirm_env

if [[ "$confirm_env" != "$CURRENT_ENV" ]]; then
  echo "Confirmation mismatch. Aborting."
  exit 1
fi

terraform destroy

echo "Infrastructure destroyed."
