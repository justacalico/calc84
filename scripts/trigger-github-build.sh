#!/bin/bash
set -euo pipefail

# Trigger a GitHub Actions "Build and Release" workflow and block while
# streaming its output, so the GitLab job duration matches the GitHub run and
# the logs appear in GitLab as if it were a native runner.

REPO="justacalico/calc84"
WORKFLOW="build.yml"

REF="${1:-main}"
BUILD_ALL="${2:-true}"
CREATE_RELEASE="${3:-false}"
PUSH_REF="${4:-HEAD}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The workflow must exist on GitHub's default branch before dispatch works.
if ! gh workflow view "$WORKFLOW" -R "$REPO" >/dev/null 2>&1; then
  echo "Workflow $WORKFLOW is not on GitHub yet, skipping trigger"
  exit 0
fi

# workflow_dispatch can only target refs that exist on GitHub. For merge
# request pipelines the commit is pushed to a staging branch first.
if [ "$PUSH_REF" != "HEAD" ] && [ "$PUSH_REF" != "$REF" ]; then
  git push -f github "$PUSH_REF:refs/heads/$REF"
fi
if ! git ls-remote --heads github "$REF" | grep -q .; then
  git push -f github "HEAD:refs/heads/$REF"
fi
PUSHED_SHA=$(git rev-parse "${PUSH_REF}^{commit}" 2>/dev/null || git rev-parse "HEAD^{commit}")

MERGE_REQUEST_ID="${CI_MERGE_REQUEST_IID:-}"
MERGE_REQUEST_URL="${CI_MERGE_REQUEST_URL:-}"
if [ -n "$MERGE_REQUEST_ID" ] && [ -z "$MERGE_REQUEST_URL" ]; then
  MERGE_REQUEST_URL="${CI_SERVER_URL:-https://gitlab.com}/${CI_PROJECT_PATH}/-/merge_requests/${MERGE_REQUEST_ID}"
fi

echo "Triggering GitHub workflow: $WORKFLOW @ $REF (build_all=$BUILD_ALL, create_release=$CREATE_RELEASE, merge_request_id=$MERGE_REQUEST_ID)"
# Record the dispatch time (minus a clock-skew margin) so the run lookup can
# ignore older runs for the same commit.
TRIGGER_TS=$(date -u -d "@$(( $(date +%s) - 120 ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
if ! gh workflow run "$WORKFLOW" -R "$REPO" --ref "$REF" \
  -F build_all="$BUILD_ALL" \
  -F create_release="$CREATE_RELEASE" \
  -F merge_request_id="$MERGE_REQUEST_ID" \
  -F merge_request_url="$MERGE_REQUEST_URL"; then
  echo "Failed to trigger GitHub workflow" >&2
  exit 1
fi

# Find the run created for the commit we pushed, so each pipeline watches
# its own run instead of whatever happens to be newest on the branch.
LOOKUP_SHA="${PUSHED_SHA:-}"
if [ -z "$LOOKUP_SHA" ]; then
  echo "Could not resolve commit for $REF" >&2
  exit 1
fi
RUN_ID=$("$BASE_DIR/scripts/watch-github-run.sh" find --sha "$LOOKUP_SHA" --event workflow_dispatch --branch "$REF" --since "$TRIGGER_TS" || true)

if [ -z "${RUN_ID:-}" ]; then
  echo "Could not find GitHub run for $REF" >&2
  exit 1
fi

"$BASE_DIR/scripts/watch-github-run.sh" "$RUN_ID"
