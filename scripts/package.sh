#!/bin/bash
set -e

LAMBDA_DIR="../lambda"
ZIP_FILE="../infrastructure/modules/lambda/task_manager.zip"

echo "Packaging Lambda function..."
rm -f "$ZIP_FILE"
cd "$LAMBDA_DIR"
zip -r "$ZIP_FILE" . > /dev/null
echo "Lambda packaged at $ZIP_FILE"
