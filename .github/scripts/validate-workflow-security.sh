#!/bin/bash
set -e

# Validates GitHub Actions workflow security requirements:
# 1. No pull_request_target with PR-head checkout
# 2. No ${{ github.event.inputs.* }} interpolated directly into run: scripts

workflow_dir=".github/workflows"
errors=0

echo "Validating workflow security..."

# Check 1: pull_request_target must not check out PR head
for file in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
  [ ! -f "$file" ] && continue
  
  if grep -q "pull_request_target:" "$file"; then
    # Check if it has a checkout with PR head ref without using workflow_run pattern
    if grep -E "ref:.*github\.event\.pull_request\.(head\.sha|head\.ref)" "$file" | grep -v "workflow_run" >/dev/null 2>&1; then
      echo "❌ ERROR: $file uses pull_request_target with PR head checkout"
      echo "   Use workflow_run pattern instead (validate-json-*.yml as example)"
      errors=$((errors + 1))
    fi
  fi
done

# Check 2: No github.event.inputs.* directly in run: scripts
for file in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
  [ ! -f "$file" ] && continue
  
  # Look for run: blocks that contain github.event.inputs
  if grep -A 50 "run: |" "$file" | grep -E '\$\{\{\s*github\.event\.inputs\.' >/dev/null 2>&1; then
    echo "❌ ERROR: $file has github.event.inputs.* interpolated in run: script"
    echo "   Move inputs to step env block and reference as shell variables"
    errors=$((errors + 1))
  fi
  
  # Also check single-line run:
  if grep -E "^\s+run:.*\\\$\{\{\s*github\.event\.inputs\." "$file" >/dev/null 2>&1; then
    echo "❌ ERROR: $file has github.event.inputs.* interpolated in run: script"
    echo "   Move inputs to step env block and reference as shell variables"
    errors=$((errors + 1))
  fi
done

if [ $errors -eq 0 ]; then
  echo "✅ All workflow security checks passed"
  exit 0
else
  echo
  echo "❌ Found $errors workflow security issue(s)"
  exit 1
fi
