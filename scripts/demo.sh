#!/bin/bash
set -euo pipefail

echo "=== AI Platform Demo ==="
echo ""
echo "1. Starting infrastructure (proxy, Prometheus, Grafana, demo)..."
docker compose up -d --build proxy prometheus grafana demo

echo ""
echo "2. Waiting for services to be ready..."
until curl -sf http://localhost:8000/health > /dev/null 2>&1; do
  echo "   Waiting for proxy..."
  sleep 2
done
echo "   Proxy is ready."

until curl -sf http://localhost:9090/-/ready > /dev/null 2>&1; do
  echo "   Waiting for Prometheus..."
  sleep 2
done
echo "   Prometheus is ready."

until curl -sf http://localhost:3000/api/health > /dev/null 2>&1; do
  echo "   Waiting for Grafana..."
  sleep 2
done
echo "   Grafana is ready."

echo ""
echo "=== Service URLs ==="
echo "  Proxy API:   http://localhost:8000"
echo "  API Docs:    http://localhost:8000/docs"
echo "  Prometheus:  http://localhost:9090"
echo "  Grafana:     http://localhost:3000 (admin:admin)"
echo "  Demo UI:     http://localhost:8080"
echo ""

echo "=== Quick API Test ==="
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Say hello in one word"}]}' | python3 -m json.tool

echo ""
echo "=== Starting Load Test ==="
echo "  Phase 1 (0-60s):  Baseline 100 req/min"
echo "  Phase 2 (60-120s): Ramp up to 5000 req/min"
echo "  Phase 3 (120-180s): Sustained peak"
echo "  Phase 4 (180-240s): Cool down to 0"
echo ""

docker compose up load-generator

echo ""
echo "=== Demo Complete ==="
echo "Open Grafana at http://localhost:3000 to view metrics."
echo "Run './scripts/cleanup.sh' to stop all services."
