# Invalidate AWS CloudFront Action Changelog

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
