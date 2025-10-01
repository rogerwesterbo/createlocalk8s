#!/bin/bash
# Wrapper script for create-cluster.sh with more intuitive naming
# All arguments are passed through to the main script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/create-cluster.sh" "$@"
