#!/bin/bash -l

set -eo pipefail

# check configuration

err=0

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

# run

# Create a dedicated profile for this action to avoid
# conflicts with other actions.
# https://github.com/jakejarvis/s3-sync-action/issues/1
aws configure --profile invalidate-cloudfront-action <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
${AWS_REGION}
text
EOF

# Set it here to avoid logging keys/secrets
if [ "$DEBUG" = "1" ]; then
  echo "*** Enabling debug output (set -x)"
  set -x
fi

# Ensure we have jq-1.6
jq="jq"
if  [[ ! -x "$(command -v $jq)" || "$($jq --version)" != "jq-1.6" ]]; then
  if [[ $(uname) == "Darwin" ]]; then
    jqbin="jq-osx-amd64"
  elif [[ $(uname) == "Linux" ]]; then
    jqbin="jq-linux64"
  fi
  if [[ -n "$jqbin" ]]; then
    jq="/usr/local/bin/jq16"
    wget -O $jq https://github.com/stedolan/jq/releases/download/jq-1.6/$jqbin
    chmod 755 $jq
  fi
fi

if [[ -n "$PATHS_FROM" ]]; then
  echo "*** Reading PATHS from $PATHS_FROM"
  if [[ ! -f  $PATHS_FROM ]]; then
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
IFS=' ' read -r -a PATHS_ARR <<< "$PATHS"
echo -n "${PATHS}" > "${RUNNER_TEMP}/paths.txt"
JSON_PATHS=$($jq --null-input --compact-output --monochrome-output --rawfile inarr "${RUNNER_TEMP}/paths.txt" '$inarr | rtrimstr(" ") | rtrimstr("\n") | split(" ")')
LEN="${#PATHS_ARR[@]}"
CR="$(date +"%s")$RANDOM"
cat <<-EOF > "${RUNNER_TEMP}/invalidation-batch.json"
{ "InvalidationBatch": { "Paths": { "Quantity": ${LEN}, "Items": ${JSON_PATHS} }, "CallerReference": "${CR}" } }
EOF

if [ "$DEBUG" = "1" ]; then
  echo "> wrote ${RUNNER_TEMP}/invalidation-batch.json"
  cat "${RUNNER_TEMP}/invalidation-batch.json"
fi

# Use our dedicated profile and suppress verbose messages.
# Support v1.x of the awscli which does not have this flag
[[ "$(aws --version)" =~ "cli/2" ]] && pagerflag="--no-cli-pager"
aws $pagerflag --profile invalidate-cloudfront-action \
  cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION" \
  --cli-input-json "file://${RUNNER_TEMP}/invalidation-batch.json"
