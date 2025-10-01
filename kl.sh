#!/bin/bash
# Short wrapper script for create-cluster.sh
# All arguments are passed through to the main script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/create-cluster.sh" "$@"
