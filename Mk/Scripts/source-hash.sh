#!/bin/sh

set -eu

if command -v sha256 >/dev/null 2>&1; then
	sha256 -q
elif command -v sha256sum >/dev/null 2>&1; then
	sha256sum | awk '{ print $1 }'
elif command -v shasum >/dev/null 2>&1; then
	shasum -a 256 | awk '{ print $1 }'
else
	printf '  ERR     no SHA256 command is available\n' >&2
	exit 1
fi
