#!/bin/bash

# GitIngest command for analyzing public GitHub repositories
# Usage: /gitingest <github-url>

if [ $# -eq 0 ]; then
    echo "Usage: /gitingest <github-url>"
    echo "Example: /gitingest https://github.com/user/repo"
    exit 1
fi

GITHUB_URL="$1"

# Validate that it's a GitHub URL
if [[ ! "$GITHUB_URL" =~ ^https://github\.com/ ]]; then
    echo "Error: Please provide a valid GitHub URL"
    exit 1
fi

# Check if gitingest is installed
if ! command -v gitingest &> /dev/null; then
    echo "gitingest is not installed."
    read -p "Install gitingest now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing gitingest..."
        if [ -n "$VIRTUAL_ENV" ]; then
            pip install gitingest
        else
            pip install --user gitingest
        fi
    else
        echo "Installation cancelled. gitingest is required to use this command."
        exit 1
    fi
fi

# Run gitingest and output to stdout
echo "Analyzing repository: $GITHUB_URL"
echo "This may take a moment..."
echo "---"
gitingest "$GITHUB_URL" -o -
