#!/bin/bash
set -e

cd "$(dirname "$0")"
./package.sh

echo "Deploying infrastructure..."
cd ../infrastructure

terraform init
terraform apply -auto-approve

echo "Deployment complete."
