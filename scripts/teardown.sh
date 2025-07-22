#!/bin/bash
set -e

cd "$(dirname "$0")"
cd ../infrastructure
terraform destroy -auto-approve

echo "Infrastructure destroyed."
