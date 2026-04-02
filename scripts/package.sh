#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAMBDA_DIR="$SCRIPT_DIR/../lambda"
ZIP_FILE="$SCRIPT_DIR/../infrastructure/modules/lambda/task_manager.zip"
PACKAGE_DIR="$SCRIPT_DIR/../build/lambda"

echo "Installing dependencies..."
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
pip install -r "$LAMBDA_DIR/requirements.txt" -t "$PACKAGE_DIR" --quiet

echo "Packaging Lambda function..."
cp -r "$LAMBDA_DIR"/. "$PACKAGE_DIR"/
rm -f "$ZIP_FILE"
cd "$PACKAGE_DIR"
zip -r "$ZIP_FILE" . > /dev/null
echo "Lambda packaged at $ZIP_FILE"
