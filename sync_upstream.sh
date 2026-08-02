#!/usr/bin/env bash
#
# sync_upstream.sh - Sync fork with official jellyfin/jellycon upstream
#
# PURPOSE: Helps maintainers pull upstream releases and re-apply custom changes.
# AUDIENCE: Both humans and AI agents (clear output, safe by default).
# SAFETY: Default behavior is READ-ONLY analysis. Requires --merge to modify branch.
#
# USAGE:
#   ./sync_upstream.sh [--help] [--remote <name>] [--repo <url>] [--fetch] [--base <ref>]
#                     [--merge] [--dry-run] [--version-check] [--require-branch]
#
# OPTIONS:
#   --help              Show this help message and exit
#   --remote <name>     Upstream remote name (default: upstream)
#   --repo <url>        Upstream repo URL to add if remote missing (default: https://github.com/jellyfin/jellycon.git)
#   --fetch             Fetch upstream (safe, default: run fetch)
#   --base <ref>        Branch/ref to sync against (default: master)
#   --merge             Perform the merge/rebase of upstream into current branch
#   --dry-run           Show what WOULD happen (default unless --merge)
#   --version-check     Compare upstream version with fork version and documented base
#   --require-branch    Error if not on release/1.0.3-beta branch
#
# EXAMPLES:
#   Analysis (default):        ./sync_upstream.sh
#   With version check:        ./sync_upstream.sh --version-check
#   Merge upstream master:     ./sync_upstream.sh --merge --base master
#   Strict branch check:       ./sync_upstream.sh --merge --require-branch
#

set -euo pipefail

# Default values
REMOTE_NAME="upstream"
REMOTE_URL="https://github.com/jellyfin/jellycon.git"
BASE_REF="master"
DO_FETCH=true
DO_MERGE=false
DRY_RUN=true
VERSION_CHECK=false
REQUIRE_BRANCH=false
TARGET_BRANCH="release/1.0.3-beta"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      sed -n '/^# USAGE/,/^#$/p' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    --remote)
      REMOTE_NAME="$2"
      shift 2
      ;;
    --repo)
      REMOTE_URL="$2"
      shift 2
      ;;
    --fetch)
      DO_FETCH=true
      shift
      ;;
    --base)
      BASE_REF="$2"
      shift 2
      ;;
    --merge)
      DO_MERGE=true
      DRY_RUN=false
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --version-check)
      VERSION_CHECK=true
      shift
      ;;
    --require-branch)
      REQUIRE_BRANCH=true
      shift
      ;;
    *)
      echo "[sync] ERROR: Unknown option: $1" >&2
      echo "[sync] Run --help for usage" >&2
      exit 1
      ;;
  esac
done

# Helper functions
echo_prefix() {
  echo "[sync] $*"
}

# Step 1: Check it's a git repo
echo_prefix "Checking git repository..."
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo_prefix "ERROR: Not a git repository" >&2
  exit 1
fi

# Step 2: Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo_prefix "Current branch: $CURRENT_BRANCH"

if [[ "$REQUIRE_BRANCH" == true && "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]]; then
  echo_prefix "ERROR: Not on required branch '$TARGET_BRANCH' (current: $CURRENT_BRANCH)" >&2
  exit 1
fi

if [[ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]]; then
  echo_prefix "WARNING: Not on '$TARGET_BRANCH' branch (current: $CURRENT_BRANCH)"
fi

# Step 3: Ensure upstream remote exists
echo_prefix "Checking remote '$REMOTE_NAME'..."
if ! git remote | grep -q "^${REMOTE_NAME}$"; then
  echo_prefix "Remote '$REMOTE_NAME' not found. Adding from: $REMOTE_URL"
  if [[ "$DRY_RUN" == true ]]; then
    echo_prefix "[DRY-RUN] Would add remote: git remote add $REMOTE_NAME $REMOTE_URL"
  else
    git remote add "$REMOTE_NAME" "$REMOTE_URL"
    echo_prefix "Added remote '$REMOTE_NAME'"
  fi
else
  CURRENT_REMOTE_URL=$(git remote get-url "$REMOTE_NAME")
  echo_prefix "Remote '$REMOTE_NAME' exists: $CURRENT_REMOTE_URL"
fi

# Step 4: Fetch upstream
if [[ "$DO_FETCH" == true ]]; then
  echo_prefix "Fetching $REMOTE_NAME/$BASE_REF..."
  if [[ "$DRY_RUN" == true ]]; then
    echo_prefix "[DRY-RUN] Would fetch: git fetch $REMOTE_NAME"
  else
    git fetch "$REMOTE_NAME"
    echo_prefix "Fetch complete"
  fi
fi

# Step 5: Determine upstream release version
echo_prefix "Determining upstream version..."
UPSTREAM_VERSION=$(git show "$REMOTE_NAME/$BASE_REF:release.yaml" 2>/dev/null | grep '^version:' | head -1 | sed 's/version: //' | tr -d "'" || echo "unknown")
echo_prefix "Upstream version (from $REMOTE_NAME/$BASE_REF:release.yaml): $UPSTREAM_VERSION"

# Also try to find the highest semver tag
UPSTREAM_TAG=$(git ls-remote --tags "$REMOTE_NAME" 2>/dev/null | grep -E 'refs/tags/v?[0-9]+\.[0-9]+\.[0-9]+' | tail -1 | sed 's/.*refs.tags.\(.*\)$/\1/' || echo "none")
if [[ "$UPSTREAM_TAG" != "none" ]]; then
  echo_prefix "Latest upstream tag: $UPSTREAM_TAG"
fi

# Step 6: Print fork's current version
FORK_VERSION=$(grep '^version:' release.yaml | head -1 | sed 's/version: //' | tr -d "'" || echo "unknown")
echo_prefix "Fork version (local release.yaml): $FORK_VERSION"

# Step 7: Version check comparison
if [[ "$VERSION_CHECK" == true ]]; then
  echo_prefix "=== Version Comparison ==="
  printf "%-20s %s\n" "Upstream version:" "$UPSTREAM_VERSION"
  printf "%-20s %s\n" "Fork version:" "$FORK_VERSION"
  printf "%-20s %s\n" "Documented base:" "official v1.0.2"
  echo ""
  
  # Simple check if upstream looks newer (very basic semver comparison)
  if [[ "$UPSTREAM_VERSION" != "unknown" && "$UPSTREAM_VERSION" != "1.0.2" ]]; then
    echo_prefix "NOTE: Upstream version differs from documented base (v1.0.2)"
  fi
fi

# Step 8: Show commit summary
echo_prefix "=== Commit Summary ==="

# Find merge base
MERGE_BASE=$(git merge-base "HEAD" "$REMOTE_NAME/$BASE_REF" 2>/dev/null || echo "")
if [[ -n "$MERGE_BASE" ]]; then
  echo_prefix "Merge base: $MERGE_BASE"
  echo ""
  
  echo_prefix "UPSTREAM NEW (will be merged):"
  git log --oneline "$MERGE_BASE..$REMOTE_NAME/$BASE_REF" 2>/dev/null || echo_prefix "No upstream commits found"
  echo ""
  
  echo_prefix "LOCAL CUSTOM (must be preserved):"
  git log --oneline "$MERGE_BASE..HEAD" 2>/dev/null || echo_prefix "No local commits found"
else
  echo_prefix "Could not determine merge base (branches may have diverged completely)"
fi

# Step 9: Perform merge if requested
if [[ "$DO_MERGE" == true ]]; then
  echo_prefix "=== Performing Merge ==="
  echo_prefix "Merging $REMOTE_NAME/$BASE_REF into $CURRENT_BRANCH..."
  
  if [[ "$DRY_RUN" == true ]]; then
    echo_prefix "[DRY-RUN] Would merge: git merge $REMOTE_NAME/$BASE_REF"
  else
    if git merge "$REMOTE_NAME/$BASE_REF"; then
      echo_prefix "Merge completed successfully"
    else
      echo_prefix "Merge encountered conflicts or errors"
      echo_prefix "Please resolve conflicts manually, then run:"
      echo_prefix "  git status"
      echo_prefix "After resolving, verify the custom files checklist below"
      exit 1
    fi
  fi
fi

# Step 10: Always print custom files checklist
echo_prefix ""
echo_prefix "=== Custom Files Checklist ==="
echo_prefix "After merge, verify these custom changes are still intact:"
echo_prefix "  - resources/lib/menu_functions.py (show_filter_menu, get_filtered_list_url, normalize_url_for_filtering, Favorites entry)"
echo_prefix "  - resources/lib/dir_functions.py (is_filterable_list, build_filter_menu_url, content-type mappings, gif download trigger)"
echo_prefix "  - resources/lib/item_functions.py (apply_cached_gif_art, get_art proxy/local gif paths, PORT_NUMBER=24276)"
echo_prefix "  - resources/lib/image_server.py (/gif/ proxy endpoint)"
echo_prefix "  - resources/lib/gif_cache.py (NEW file)"
echo_prefix "  - resources/lib/functions.py (SHOW_FILTERS mode)"
echo_prefix "  - resources/language/.../strings.po (strings 30683-30687)"
echo_prefix "  - release.yaml (version notation with ~beta)"
echo_prefix ""
echo_prefix "See CUSTOM_CHANGES.md for full details on custom features."

if [[ "$DO_MERGE" == true && "$DRY_RUN" == false ]]; then
  echo_prefix "Next steps:"
  echo_prefix "  1. Resolve any merge conflicts if present"
  echo_prefix "  2. Verify the custom files checklist above"
  echo_prefix "  3. Test the addon"
  echo_prefix "  4. Commit the merge if satisfied"
  echo_prefix "  5. Push when ready: git push origin $CURRENT_BRANCH"
fi

echo_prefix "Done."
