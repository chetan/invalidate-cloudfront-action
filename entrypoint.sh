#!/bin/sh -l

set -e

# check configuration

err=0

if [ -z "$DISTRIBUTION" ]; then
  echo "error: DISTRIBUTION is not set"
  err=1
fi

if [ -z "$PATHS" ]; then
  echo "error: PATHS is not set"
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

# Use our dedicated profile and suppress verbose messages.
# All other flags are optional via `args:` directive.
aws --profile invalidate-cloudfront-action \
  cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION" \
  --paths $PATHS \
  $*
