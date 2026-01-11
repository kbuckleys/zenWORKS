#!/usr/bin/env bash

# FAKE TEST DATA - guaranteed "5"
repo_updates=2
aur_updates=3
total=5

if [[ $total -gt 0 ]]; then
  echo "{\"text\": \"$total\", \"class\": \"pending-updates\", \"tooltip\": \"Repo: $repo_updates AUR: $aur_updates Total: $total\"}"
else
  echo "{\"text\": \"\", \"class\": \"updated\"}"
fi
