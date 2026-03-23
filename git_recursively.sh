#!/usr/bin/env bash

find . -type d -name ".git" 2>/dev/null | while read -r gitdir; do
    repo_dir=$(dirname "$gitdir")
    echo "→ $repo_dir"
    (cd "$repo_dir" && git pull --quiet --ff-only) && echo "   updated" || echo "   failed/skipped"
done



# Even shorter one-liner version:
# find . -type d -name ".git" -execdir git pull --quiet --ff-only \;