#!/bin/bash
set -euo pipefail

echo "=== AI Platform Cleanup ==="
docker compose down --remove-orphans
echo "All services stopped and removed."
