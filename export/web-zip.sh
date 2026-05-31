#!/bin/bash

set -e
set -x

WEB_DIR="web"
ZIP_NAME="nomizo_web.zip"

cd "$WEB_DIR"

cp -f nomizo.html index.html

rm -f "../$ZIP_NAME"

zip -r "../$ZIP_NAME" ./*

echo "Created $ZIP_NAME"

set +x
