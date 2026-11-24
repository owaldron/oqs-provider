#!/bin/bash
# usage: snapshot.sh <provider-dir> <outdir> [extra openssl args...]
set -u
P=$1; O=$2; shift 2
mkdir -p "$O"
OSSL=/opt/homebrew/opt/openssl@4/bin/openssl
A=(-provider-path "$P" -provider oqsprovider -provider default)
for k in kem-algorithms signature-algorithms key-managers encoders decoders; do
  $OSSL list -$k "${A[@]}" 2>&1 | grep "@ oqsprovider" | sed 's/^ *//' | sort > "$O/$k.txt"
done
$OSSL list -tls-groups -tls1_3 "${A[@]}" 2>&1 | tr ':' '\n' | sort > "$O/tls-groups.txt"
$OSSL list -tls-signature-algorithms "${A[@]}" 2>&1 | tr ':' '\n' | sed 's/^ *//' | sort > "$O/tls-sigalgs.txt"
wc -l "$O"/*.txt
