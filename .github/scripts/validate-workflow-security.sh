#!/bin/bash
set -e

# Validates GitHub Actions workflow security requirements:
# 1. No pull_request_target with PR-head checkout
# 2. No ${{ github.event.* }} interpolated directly into run: scripts
# 3. All uses: must be pinned to 40-character SHA

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

# Check 2: No github.event.* directly in run: scripts
for file in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
  [ ! -f "$file" ] && continue
  
  # Extract only the run: script blocks and check them
  # Use awk to extract from "run: |" or "run:" to the next step boundary
  awk '
    /^[[:space:]]+run:[[:space:]]*\|/ { in_run=1; next }
    /^[[:space:]]+run:[[:space:]]/ && !/^[[:space:]]+run:[[:space:]]*#/ { 
      if ($0 ~ /\$\{\{.*github\.event\./) {
        print NR ":" $0
      }
      next
    }
    in_run {
      if (/^[[:space:]]*$/) next
      if (/^[[:space:]]+[a-z_-]+:/ && !/^[[:space:]]+[a-z_-]+:[[:space:]]*\$\{\{/) { in_run=0; next }
      if ($0 ~ /\$\{\{.*github\.event\./) {
        print NR ":" $0
      }
    }
  ' "$file" > /tmp/run_check_$$
  
  if [ -s /tmp/run_check_$$ ]; then
    echo "❌ ERROR: $file has github.event.* interpolated in run: script"
    echo "   Move to step env block and reference as shell variables"
    cat /tmp/run_check_$$
    errors=$((errors + 1))
  fi
  rm -f /tmp/run_check_$$
done

# Check 3: All uses: must be pinned to 40-char SHA
for file in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
  [ ! -f "$file" ] && continue
  
  # Find uses: lines that use @tag instead of @sha
  while IFS= read -r line; do
    # Extract the action reference after uses:
    if [[ "$line" =~ uses:[[:space:]]*([^@]+)@([^[:space:]#]+) ]]; then
      ref="${BASH_REMATCH[2]}"
      # Check if it's NOT a 40-character hex SHA
      if ! [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
        echo "❌ ERROR: $file has unpinned action: uses: ${BASH_REMATCH[1]}@${ref}"
        echo "   Pin to SHA with: git ls-remote https://github.com/${BASH_REMATCH[1]} refs/tags/${ref}"
        errors=$((errors + 1))
      fi
    fi
  done < <(grep "uses:" "$file" | grep -v "^#")
done

if [ $errors -eq 0 ]; then
  echo "✅ All workflow security checks passed"
  exit 0
else
  echo
  echo "❌ Found $errors workflow security issue(s)"
  exit 1
fi
