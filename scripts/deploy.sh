#!/bin/bash
set -e

cd "$(dirname "$0")"
./package.sh

echo "Planning infrastructure..."
cd ../infrastructure

terraform init
terraform plan -out=tfplan

echo ""
read -p "Apply this plan? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  rm -f tfplan
  exit 1
fi

terraform apply tfplan
rm -f tfplan

echo "Deployment complete."
