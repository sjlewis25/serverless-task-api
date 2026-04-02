#!/bin/bash
set -e

cd "$(dirname "$0")"
./package.sh

echo "Planning infrastructure..."
cd ../infrastructure

# Load backend config from tfvars
BUCKET=$(grep tf_state_bucket terraform.tfvars | cut -d'"' -f2)
TABLE=$(grep tf_lock_table  terraform.tfvars | cut -d'"' -f2)
REGION=$(grep '^region'     terraform.tfvars | cut -d'"' -f2)
ENV=$(grep '^environment'   terraform.tfvars | cut -d'"' -f2)
PROJECT=$(grep '^project'   terraform.tfvars | cut -d'"' -f2)

terraform init \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=${PROJECT}/${ENV}.tfstate" \
  -backend-config="region=${REGION}" \
  -backend-config="dynamodb_table=${TABLE}"

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
