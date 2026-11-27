#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
OUT_DIR="dist"
mkdir -p "$OUT_DIR"

LDFLAGS="-s -w"

echo "Building Windows amd64..."
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="$LDFLAGS" -o "$OUT_DIR/snispoof-client-windows-amd64.exe" snispoof-client.go

echo "Building Linux amd64..."
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="$LDFLAGS" -o "$OUT_DIR/snispoof-client-linux-amd64" snispoof-client.go

echo "Building Linux arm64..."
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="$LDFLAGS" -o "$OUT_DIR/snispoof-client-linux-arm64" snispoof-client.go

echo "Building Linux arm (armv7)..."
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -ldflags="$LDFLAGS" -o "$OUT_DIR/snispoof-client-linux-arm" snispoof-client.go

echo "Building macOS amd64 & arm64..."
GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="$LDFLAGS" -o "$OUT_DIR/snispoof-client-darwin-amd64" snispoof-client.go
GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="$LDFLAGS" -o "$OUT_DIR/snispoof-client-darwin-arm64" snispoof-client.go

echo "Done! Binaries in desktop/$OUT_DIR/:"
ls -lh "$OUT_DIR"
