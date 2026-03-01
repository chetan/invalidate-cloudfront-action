#!/bin/bash -l

set -eo pipefail

# check configuration

err=0
aws_flags=""

if [ -z "$DISTRIBUTION" ]; then
  echo "error: DISTRIBUTION is not set"
  err=1
fi

if [[ -z "$PATHS" && -z "$PATHS_FROM" ]]; then
  echo "error: PATHS or PATHS_FROM is not set"
  err=1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "error: AWS_ACCESS_KEY_ID is not set"
  err=1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "error: AWS_SECRET_ACCESS_KEY is not set"
  err=1
fi

if [ -z "$AWS_REGION" ]; then
  echo "error: AWS_REGION is not set"
  err=1
fi

if [ $err -eq 1 ]; then
  exit 1
fi

if [ "$DEBUG_AWS" = "1" ]; then
  aws_flags="${aws_flags} --debug"
fi

# run

# Set it here to avoid logging keys/secrets
if [ "$DEBUG" = "1" ]; then
  echo "*** Enabling debug output (set -x)"
  set -x
fi

# Ensure we have jq-1.6 or above
jq="jq"
JQ_MIN_VER="1.6"

check_jq() {
  if ! command -v $jq >/dev/null 2>&1; then
    return 1
  fi
  local version=$($jq --version | cut -d'-' -f2)
  # Compare versions by removing all but the first period (e.g., 1.8.1 -> 1.81)
  local clean_version=$(echo "$version" | sed 's/\.//2')
  if (( $(echo "$clean_version < ${JQ_MIN_VER}" | bc -l) )); then
    return 1
  fi
  return 0
}

install_jq() {
  local jqbin
  if [[ $(uname) == "Darwin" ]]; then
    jqbin="jq-osx-amd64"
  elif [[ $(uname) == "Linux" ]]; then
    jqbin="jq-linux64"
  else
    echo "Unsupported OS for jq installation. Please install jq ${JQ_MIN_VER} or above manually."
    exit 1
  fi
  jq="/usr/local/bin/jq16"
  wget -nv -O $jq https://github.com/jqlang/jq/releases/download/jq-${JQ_MIN_VER}/$jqbin
  chmod 755 $jq
}

if [[ "$INSTALL_JQ" == "1" ]] || ! check_jq; then
  echo "* jq ${JQ_MIN_VER} or above is required but not found. Installing jq ${JQ_MIN_VER}..."
  install_jq
fi

# Slurp paths from file
if [[ -n "$PATHS_FROM" ]]; then
  echo "*** Reading PATHS from $PATHS_FROM"
  if [[ ! -f $PATHS_FROM ]]; then
    echo "PATHS file not found. nothing to do. exiting"
    exit 0
  fi
  PATHS=$(cat $PATHS_FROM | tr '\n' ' ')
  echo "PATHS=$PATHS"
  if [[ -z "$PATHS" ]]; then
    echo "PATHS is empty. nothing to do. exiting"
    exit 0
  fi
fi

# Handle multiple space-separated paths, particularly containing wildcards.
# i.e., if PATHS="/* /foo"
IFS=' ' read -r -a PATHS_ARR <<<"$PATHS"
echo -n "${PATHS}" >"${RUNNER_TEMP}/paths.txt"
JSON_PATHS=$($jq --null-input --compact-output --monochrome-output --rawfile inarr "${RUNNER_TEMP}/paths.txt" '$inarr | rtrimstr(" ") | rtrimstr("\n") | split(" ")')
LEN="${#PATHS_ARR[@]}"
CR="$(date +"%s")$RANDOM"
cat <<-EOF >"${RUNNER_TEMP}/invalidation-batch.json"
{ "InvalidationBatch": { "Paths": { "Quantity": ${LEN}, "Items": ${JSON_PATHS} }, "CallerReference": "${CR}" } }
EOF

if [ "$DEBUG" = "1" ]; then
  echo "> wrote ${RUNNER_TEMP}/invalidation-batch.json"
  cat "${RUNNER_TEMP}/invalidation-batch.json"
fi

export AWS_MAX_ATTEMPTS=3

# Support v1.x of the awscli which does not have this flag
[[ "$(aws --version)" =~ "cli/2" ]] && aws_flags="${aws_flags} --no-cli-pager"
aws $aws_flags \
  cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION" \
  --cli-input-json "file://${RUNNER_TEMP}/invalidation-batch.json"
