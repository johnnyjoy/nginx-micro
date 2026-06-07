# Vendored release-signing public keys (nginx + OpenSSL)

These are the OpenPGP public keys used to sign the nginx and OpenSSL release
tarballs (`*.tar.gz.asc`). They are **vendored here on purpose**: the Docker
build imports *only* these reviewed keys and refuses any tarball whose signature
is not made by one of the pinned fingerprints below.

This avoids the weaker pattern of fetching keys from the artifact's own origin
at build time and verifying a tarball from that same origin against them — which
gives an attacker who controls that origin the ability to supply both a
malicious tarball and a matching key.

## Pinned primary fingerprints

### nginx — `NGINX_GPG_FINGERPRINTS` (any of these is accepted)

| File                | Owner                                     | Primary key fingerprint                    |
| ------------------- | ----------------------------------------- | ------------------------------------------ |
| `arut.key`          | Roman Arutyunyan                          | `43387825DDB1BB97EC36BA5D007C8D7C15D87369` |
| `nginx_signing.key` | nginx signing key <signing-key@nginx.com> | `8540A6F18833A80E9C1653A42FD21310B49F6B46` |
| `pluknet.key`       | Sergey Kandaurov                          | `D6786CE303D9A9022998DC6CC8464D549AF75C0A` |
| `sb.key`            | Sergey Budnevitch                         | `7338973069ED3F443F4D37DFA64FD5B17ADB39A8` |
| `thresh.key`        | Konstantin Pavlov                         | `13C82A63B603576156E30A4EA0EA981B66B0D967` |

### OpenSSL — `OPENSSL_GPG_FINGERPRINT`

| File          | Owner                            | Primary key fingerprint                    |
| ------------- | -------------------------------- | ------------------------------------------ |
| `openssl.key` | OpenSSL <openssl@openssl.org>    | `BA5473A2B0587B07FB27CF2D216094DFD0CB81EF` |

## How these were obtained

nginx keys — downloaded from the keys linked on <https://nginx.org/en/pgp_keys.html>:

```sh
for k in arut nginx_signing pluknet sb thresh; do
  wget -O "keys/${k}.key" "https://nginx.org/keys/${k}.key"
done
```

OpenSSL key — the key that signed recent releases (issuer of
`openssl-<version>.tar.gz.asc`), fetched by fingerprint:

```sh
wget -O keys/openssl.key \
  "https://keys.openpgp.org/vks/v1/by-fingerprint/BA5473A2B0587B07FB27CF2D216094DFD0CB81EF"
```

## Verifying / refreshing

Re-derive the fingerprints from the vendored files and compare against the
table above before trusting any change to this directory:

```sh
export GNUPGHOME="$(mktemp -d)"
for f in keys/*.key; do
  echo "--- $f ---"
  gpg --quiet --with-colons --import-options show-only --import "$f" \
    | awk -F: '/^fpr:/ { print $10; exit }'
done
```

When the nginx team rotates or adds a signer, add the new `.key` file here and
add its primary fingerprint to `NGINX_GPG_FINGERPRINTS` in the `Dockerfile`.
Treat any unexpected fingerprint change as a security event.
