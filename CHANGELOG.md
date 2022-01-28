# Invalidate AWS CloudFront Action Changelog

## v2.3

### Fixes

- support for AWS credentials via OIDC ([#12](https://github.com/chetan/invalidate-cloudfront-action/issues/12))

## v2.2

### Fixes

- added support for Ubuntu 18.04 which has older versions of `jq` and `awscli`

## v2.1

### Fixes

- corrected handling of file input via `PATHS_FROM` (properly paths, one per
  line)

## v2.0

### Additions

- changes the invocation method from docker/container to composite action which
  means it can now be run on macos or windows environments

### Fixes

- minor path-handling change to work on Windows

## v1.3

### Additions

- added PATHS_FROM option for reading invalidation paths from the given file

## v1.2

### Fixes

- Fix invalidation of multiple paths

## v1.1

### Fixes

- invalidation of multiple space-separated paths

### Additions

- added DEBUG="1" flag for extra troubleshooting.

## v1.0

First cut! Works as advertised.
