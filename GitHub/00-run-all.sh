#!/usr/bin/env bash
# 00-run-all.sh
# Summary: Run all GitHub setup scripts from 01- to 11- sequentially.
#
# Usage:
#   OWNER="username" REPOS="repo1,repo2" bash 00-run-all.sh
#   or
#   OWNER="username" bash 00-run-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the range of scripts to run
START=1
END=11

echo "Starting execution of scripts from 01- to 11-..."
echo "================================================"

for i in $(seq -f "%02g" $START $END); do
    SCRIPT="${SCRIPT_DIR}/${i}-*.sh"
    
    # Find the first matching script
    SCRIPT_PATH=$(ls $SCRIPT 2>/dev/null | head -1)
    
    if [[ -z "$SCRIPT_PATH" ]]; then
        echo "Warning: No script found for ${i}-*"
        continue
    fi
    
    echo ""
    echo "Running: $SCRIPT_PATH"
    echo "--------------------------------------------------"
    
    # Run the script, passing through any arguments
    bash "$SCRIPT_PATH" "${@}"
    
    echo "Completed: $SCRIPT_PATH"
done

echo ""
echo "================================================"
echo "All scripts from 01- to 11- have been executed."
