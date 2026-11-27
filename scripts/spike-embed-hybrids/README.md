# Spike: embedding hybrid-provider in oqsprovider

Throwaway tooling for the `spike/embed-hybrid-provider` branch (see oqs-provider issue 847).

Build three trees side by side in one work dir `$W`:

```sh
# baseline: this repo with the option OFF (identical to main)
cmake -GNinja -S . -B $W/oqs-baseline -Dliboqs_DIR=... -DOPENSSL_ROOT_DIR=...
# embedded: hybrids served by hybrid-provider (branch spike/embed-in-oqsprovider)
cmake -GNinja -S . -B $W/oqs-embed -Dliboqs_DIR=... -DOPENSSL_ROOT_DIR=... \
      -DOQS_PROVIDER_EMBED_HYBRIDS=ON -DHYBRID_PROVIDER_SOURCE_DIR=/path/to/hybrid-provider
```

- `snapshot.sh <provider-dir> <out-dir>`: dumps what the provider advertises
  (KEMs, sigs, keymgmt, encoders, decoders, TLS groups, TLS sigalgs) for diffing.
- `interop.sh $W`: cross-checks certs, keys and signatures, plus TLS handshakes,
  between `oqs-baseline` and `oqs-embed` in both directions.

Both assume the OpenSSL CLI at `/opt/homebrew/opt/openssl@4/bin/openssl`.
