#!/bin/bash
set -eu

# Run from core/. Keep the pinned module cache and the checkout untouched.
module=github.com/xtls/xray-core
stage=$(mktemp -d "${TMPDIR:-/tmp}/throne-mux.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
cp -R "$PWD" "$stage/core"
cd "$stage/core"
export GOWORK=off
if [[ -n "${THRONE_XRAY_MODFILE:-}" ]]; then
  cp "$THRONE_XRAY_MODFILE" go.mod
  cp "${THRONE_XRAY_MODFILE%.mod}.sum" go.sum
fi
go mod download "$module"
source_dir=$(go list -m -f '{{.Dir}}' "$module")
cp -R "$source_dir" "$stage/xray"
chmod -R u+w "$stage/xray"
(cd "$stage/xray" && patch -f -F 0 -p1 < "$stage/core/patches/xray-mux-context.patch")
(cd "$stage/xray" && patch -f -F 0 -p1 < "$stage/core/patches/xray-probe-lifetime.patch")
(cd "$stage/xray" && patch -f -F 0 -p1 < "$stage/core/patches/xray-vless-preconnect.patch")
# A version-specific legacy replacement takes precedence over a wildcard.
version=$(go list -m -f '{{.Version}}' "$module")
go mod edit "-replace=$module@$version=../xray"
"$@"
