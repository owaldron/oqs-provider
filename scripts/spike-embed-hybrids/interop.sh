#!/bin/bash
# Cross-implementation checks: baseline oqsprovider (B) vs embedded hybrid-provider build (E).
S=$1; W=$S/interop; cd "$W" || exit 1
OSSL=/opt/homebrew/opt/openssl@4/bin/openssl
B=(-provider-path "$S/oqs-baseline/lib" -provider oqsprovider -provider default)
E=(-provider-path "$S/oqs-embed/lib" -provider oqsprovider -provider default)
pass=0; fail=0
ok(){ echo "PASS $*"; pass=$((pass+1)); }; ko(){ echo "FAIL $*"; fail=$((fail+1)); }
side(){ [ "$1" = B ] && echo "${B[@]}" || echo "${E[@]}"; }

for alg in p256_mldsa44 p384_mldsa65 rsa3072_mldsa44 p256_falcon512 p384_mayo3 p256_ov_ip_pkc; do
  for gen in B E; do
    ver=$([ $gen = B ] && echo E || echo B)
    k=$W/$alg.$gen.key; c=$W/$alg.$gen.crt
    if $OSSL req -x509 -new -newkey $alg -keyout $k -out $c -nodes -subj "/CN=$alg-$gen" -days 1 $(side $gen) >/dev/null 2>$W/err; then
      if $OSSL verify $(side $ver) -CAfile $c $c >/dev/null 2>$W/err; then ok "$alg: cert by $gen verifies under $ver"; else ko "$alg: cert by $gen verify under $ver: $(head -c 200 $W/err)"; fi
      if $OSSL pkey -in $k -noout $(side $gen) 2>/dev/null; then ok "$alg: privkey by $gen parses under $gen (control)"; else ko "$alg: privkey by $gen parse under $gen (control)"; fi
      if $OSSL pkey -in $k -noout $(side $ver) 2>$W/err; then ok "$alg: privkey by $gen parses under $ver"; else ko "$alg: privkey by $gen parse under $ver: $(head -c 200 $W/err)"; fi
      echo msg > $W/m; if $OSSL pkeyutl -sign -rawin -inkey $k -in $W/m -out $W/sig $(side $gen) 2>/dev/null && $OSSL pkeyutl -verify -rawin -certin -inkey $c -in $W/m -sigfile $W/sig $(side $ver) >/dev/null 2>$W/err; then ok "$alg: sig by $gen verifies under $ver"; else ko "$alg: sig by $gen under $ver: $(head -c 200 $W/err)"; fi
    else ko "$alg: keygen/cert under $gen: $(head -c 200 $W/err)"; fi
  done
done

port=44433
tls(){ # srv cli group certalg
  local srv=$1 cli=$2 grp=$3 calg=$4; port=$((port+1))
  $OSSL s_server -accept $port -cert $W/$calg.$srv.crt -key $W/$calg.$srv.key -groups $grp -tls1_3 -www $(side $srv) >$W/srv.log 2>&1 &
  local pid=$!; sleep 0.7
  out=$(echo | $OSSL s_client -connect localhost:$port -groups $grp -CAfile $W/$calg.$srv.crt -tls1_3 $(side $cli) 2>&1)
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  if echo "$out" | grep -q "Verify return code: 0 (ok)" && echo "$out" | grep -qi "Negotiated TLS1.3 group: $grp"; then ok "TLS $grp + $calg cert: server=$srv client=$cli"
  else ko "TLS $grp + $calg: server=$srv client=$cli: $(echo "$out" | grep -iE 'error|group|verify' | head -3 | tr '\n' ' ')"; fi
}
for grp in x25519_frodo640aes p256_hqc1 x25519_mlkem512 p384_bikel3 X25519MLKEM768; do
  tls E B $grp p256_mldsa44; tls B E $grp p256_mldsa44
done
tls B B p256_hqc1 p256_mldsa44   # control
tls E E p256_hqc1 p256_mldsa44   # control
tls E E x25519_frodo640aes p256_falcon512
echo "== $pass passed, $fail failed"
