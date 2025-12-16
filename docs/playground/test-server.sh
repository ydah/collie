#!/bin/bash
# Simple HTTP server for testing the playground locally

cd "$(dirname "$0")"
echo "Starting HTTP server at http://localhost:8000"
echo "Open http://localhost:8000 in your browser"
echo "Press Ctrl+C to stop"
echo ""

# Try Python 3 first, then Python 2
if command -v python3 &> /dev/null; then
    python3 -m http.server 8000
elif command -v python &> /dev/null; then
    python -m SimpleHTTPServer 8000
else
    echo "Error: Python not found. Please install Python to run the test server."
    exit 1
fi
