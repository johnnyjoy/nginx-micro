# syntax=docker/dockerfile:1

################################################################################
# GLOBAL BUILD ARGS
################################################################################

ARG NGINX_VERSION=1.31.2
ARG OPENSSL_VERSION=4.0.1

ARG CFLAGS="-flto -fmerge-all-constants -fno-unwind-tables -fuse-linker-plugin -Os -ffunction-sections -fdata-sections -fno-ident -fno-asynchronous-unwind-tables -fstack-protector-strong -fPIE -Wno-cast-function-type -Wno-implicit-function-declaration"
ARG LDFLAGS="-flto -fuse-linker-plugin -static-pie -s -Wl,--gc-sections -Wl,-z,relro -Wl,-z,now -Wl,--build-id=none"

################################################################################
# FETCH: download/verify nginx and openssl
################################################################################
FROM alpine:edge AS fetch

ARG NGINX_VERSION
ARG OPENSSL_VERSION

RUN apk add --no-cache wget tar gnupg

WORKDIR /build

# Vendored release-signing public keys (reviewed in git; see keys/README.md).
# Imported locally so the build never trusts keys fetched from an artifact's
# own origin at build time.
COPY keys/ /tmp/keys/

# OpenSSL: pin the SHA-256 AND verify the detached PGP signature against the
# vendored OpenSSL release key. Update OPENSSL_CHECKSUM whenever OPENSSL_VERSION
# changes (download the signed asset, verify, then `sha256sum`). The checksum
# below is for OpenSSL 4.0.1.
ARG OPENSSL_CHECKSUM="2db3f3a0d6ea4b59e1f094ace2c8cd536dffb87cdc39084c5afa1e6f7f37dd09"
ARG OPENSSL_GPG_FINGERPRINT="BA5473A2B0587B07FB27CF2D216094DFD0CB81EF"
RUN set -eux; \
    wget -O openssl.tar.gz "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"; \
    wget -O openssl.tar.gz.asc "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz.asc"; \
    if [ -n "${OPENSSL_CHECKSUM}" ]; then \
        echo "${OPENSSL_CHECKSUM}  openssl.tar.gz" | sha256sum -c -; \
    fi; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --import /tmp/keys/openssl.key; \
    gpg --batch --status-fd 1 --verify openssl.tar.gz.asc openssl.tar.gz > /tmp/openssl-gpg.status; \
    sig_primary="$(awk '/^\[GNUPG:\] VALIDSIG/ { print $NF }' /tmp/openssl-gpg.status)"; \
    echo "openssl tarball signed by primary key: ${sig_primary:-<none>}"; \
    [ "${sig_primary}" = "${OPENSSL_GPG_FINGERPRINT}" ] || \
      { echo "ERROR: openssl signature is not from the pinned key (${sig_primary:-none})" >&2; exit 1; }; \
    mkdir openssl; \
    tar xzf openssl.tar.gz -C openssl --strip-components=1

WORKDIR /build

# Pinned PRIMARY fingerprints of the accepted nginx release signers (keys are
# vendored in keys/ and reviewed in git; see keys/README.md for provenance).
ARG NGINX_GPG_FINGERPRINTS="43387825DDB1BB97EC36BA5D007C8D7C15D87369 8540A6F18833A80E9C1653A42FD21310B49F6B46 D6786CE303D9A9022998DC6CC8464D549AF75C0A 7338973069ED3F443F4D37DFA64FD5B17ADB39A8 13C82A63B603576156E30A4EA0EA981B66B0D967"

# Pinned tarball SHA-256 for byte-for-byte reproducibility. MUST be updated
# whenever NGINX_VERSION changes: download the signed release asset, verify its
# PGP signature, then record `sha256sum nginx-<version>.tar.gz`. The value below
# is for nginx 1.31.2. Set to "" to disable the checksum gate (not recommended).
ARG NGINX_CHECKSUM="af2a957c41da636ddc4f883e4523c6d140b4784dbce42000c364ae5092aa473c"

# nginx: download the official signed release ASSETS from the nginx GitHub
# releases (NOT the /archive/ auto-generated tarballs, which have no .asc and
# unstable checksums), optionally checksum-pin, then verify the PGP signature
# against the locally vendored keys and assert it was made by a pinned signer.
RUN set -eux; \
    wget -O nginx.tar.gz "https://github.com/nginx/nginx/releases/download/release-${NGINX_VERSION}/nginx-${NGINX_VERSION}.tar.gz"; \
    wget -O nginx.tar.gz.asc "https://github.com/nginx/nginx/releases/download/release-${NGINX_VERSION}/nginx-${NGINX_VERSION}.tar.gz.asc"; \
    if [ -n "${NGINX_CHECKSUM}" ]; then \
        echo "${NGINX_CHECKSUM}  nginx.tar.gz" | sha256sum -c -; \
    fi; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --import /tmp/keys/nginx_signing.key /tmp/keys/arut.key /tmp/keys/pluknet.key /tmp/keys/sb.key /tmp/keys/thresh.key; \
    gpg --batch --status-fd 1 --verify nginx.tar.gz.asc nginx.tar.gz > /tmp/gpg.status; \
    sig_primary="$(awk '/^\[GNUPG:\] VALIDSIG/ { print $NF }' /tmp/gpg.status)"; \
    echo "nginx tarball signed by primary key: ${sig_primary:-<none>}"; \
    case " ${NGINX_GPG_FINGERPRINTS} " in \
      *" ${sig_primary} "*) echo "OK: signature from a pinned nginx key" ;; \
      *) echo "ERROR: nginx signature is not from a pinned key (${sig_primary:-none})" >&2; exit 1 ;; \
    esac; \
    mkdir nginx; \
    tar xzf nginx.tar.gz -C nginx --strip-components=1

################################################################################
# BUILD DEPS: all static, pcre2, zlib, upx (for optional)
################################################################################
FROM alpine:edge AS build-deps

ARG NGINX_VERSION
ARG OPENSSL_VERSION
ARG CFLAGS
ARG LDFLAGS

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk add --no-cache gcc musl-dev linux-headers make binutils wget gnupg \
      pcre2-dev pcre2-static zlib-dev zlib-static perl

RUN apk add upx || true

COPY --from=fetch /build /build

# Build minimal passwd and group to support user nginx (optional, but recommended)
RUN echo 'nginx:x:101:101:nginx:/nonexistent:/sbin/nologin' > /nginx.passwd && \
    echo 'nginx:x:101:' > /nginx.group

################################################################################
# BUILD OPENSSL (exact, robust, static, per-platform)
################################################################################
FROM build-deps AS build-openssl

ARG OPENSSL_VERSION
ARG CFLAGS
ARG LDFLAGS

WORKDIR /build/openssl

# Add logic for target arch (for multi-platform builds)
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

# EXTRA_CONF carries per-arch Configure quirks. On riscv64, OpenSSL 4.0.x's MD5
# assembly glue (crypto/md5/md5_riscv.c) references the public MD5_CTX type, which
# `no-deprecated` compiles out -> "unknown type name 'MD5_CTX'". Disabling asm on
# riscv64 skips that broken glue (riscv64 is emulated/slow anyway, so the asm
# optimization is irrelevant there). All other arches keep asm enabled.
RUN EXTRA_CONF=""; \
    case "$TARGETPLATFORM" in \
      "linux/amd64")   CONF=linux-x86_64 ;;  \
      "linux/386")     CONF=linux-x86 ;;     \
      "linux/arm/v6")  CONF=linux-armv4 ;;   \
      "linux/arm/v7")  CONF=linux-armv4 ;;   \
      "linux/arm64")   CONF=linux-aarch64 ;; \
      "linux/ppc64le") CONF=linux-ppc64le ;; \
      "linux/s390x")   CONF=linux64-s390x ;; \
      "linux/riscv64") CONF=linux64-riscv64; EXTRA_CONF="no-asm" ;; \
      *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac && \
    echo "Configuring for $CONF ${EXTRA_CONF}" && \
    ./Configure ${CONF} ${EXTRA_CONF} \
        --prefix=/usr \
        no-cms \
        no-md2 \
        no-md4 \
        no-mdc2 \
        no-seed \
        no-bf \
        no-cast \
        no-des \
        no-sm2 \
        no-sm3 \
        no-sm4 \
        no-rc2 \
        no-rc4 \
        no-idea \
        no-aria \
        no-camellia \
        no-whirlpool \
        no-rmd160 \
        no-shared \
        no-tests \
        no-ssl3 \
        no-ssl3-method \
        no-srp \
        no-psk \
        no-weak-ssl-ciphers \
        no-comp \
        no-zlib \
        no-dynamic-engine \
        no-engine \
        no-dso \
        no-async \
        no-filenames \
        no-docs \
        no-deprecated \
        no-apps \
        no-dtls \
        no-srtp \
        no-ct \
        no-ts \
        no-cmp \
        no-nextprotoneg \
        no-ec2m \
        no-legacy \
        no-autoload-config \
        no-ui-console \
        --with-rand-seed=devrandom && \
    make -j"$(nproc)" && \
    make install_sw

################################################################################
# BUILD NGINX Micro (no gzip, no ssl)
################################################################################
FROM build-deps AS build-micro

ARG NGINX_VERSION CFLAGS LDFLAGS

WORKDIR /build/nginx

RUN ./configure \
    --sbin-path=/nginx \
    --pid-path="/nginx.pid" \
    --lock-path="/nginx.lock" \
    --error-log-path="/dev/stdout" \
    --http-log-path="/dev/stdout" \
    --conf-path=/conf/nginx.conf \
    --prefix="/" \
    --with-cc-opt="$CFLAGS" \
    --with-ld-opt="$LDFLAGS" \
    --with-pcre \
    --with-pcre-jit \
    --with-threads \
    --with-file-aio \
    --with-http_realip_module \
    --without-select_module \
    --without-poll_module \
    --without-http_charset_module \
    --without-http_auth_basic_module \
    --without-http_browser_module \
    --without-http_map_module \
    --without-http_autoindex_module \
    --without-http_geo_module \
    --without-http_split_clients_module \
    --without-http_userid_module \
    --without-http_empty_gif_module \
    --without-http_referer_module \
    --without-http_proxy_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    --without-http_ssi_module \
    --without-http_gzip_module \
    --without-http_memcached_module \
    --without-http_mirror_module \
    --without-http_upstream_hash_module \
    --without-http_upstream_ip_hash_module \
    --without-http_upstream_least_conn_module \
    --without-http_upstream_random_module \
    --without-http_upstream_keepalive_module \
    --without-http_upstream_zone_module && \
    make -j"$(nproc)" && \
    cp objs/nginx /nginx && \
    strip --strip-all /nginx && \
    upx --ultra-brute /nginx -o /nginx-upx || cp /nginx /nginx-upx

################################################################################
# BUILD NGINX Gzip (no SSL)
################################################################################
FROM build-deps AS build-gzip
 
ARG NGINX_VERSION CFLAGS LDFLAGS

WORKDIR /build/nginx

RUN ./configure \
    --sbin-path=/nginx \
    --pid-path="/nginx.pid" \
    --lock-path="/nginx.lock" \
    --error-log-path="/dev/stdout" \
    --http-log-path="/dev/stdout" \
    --conf-path=/conf/nginx.conf \
    --prefix="/" \
    --with-cc-opt="$CFLAGS" \
    --with-ld-opt="$LDFLAGS" \
    --with-pcre \
    --with-pcre-jit \
    --with-threads \
    --with-file-aio \
    --with-http_realip_module \
    --without-select_module \
    --without-poll_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --without-http_charset_module \
    --without-http_auth_basic_module \
    --without-http_browser_module \
    --without-http_map_module \
    --without-http_autoindex_module \
    --without-http_geo_module \
    --without-http_split_clients_module \
    --without-http_userid_module \
    --without-http_empty_gif_module \
    --without-http_referer_module \
    --without-http_proxy_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    --without-http_ssi_module \
    --without-http_memcached_module \
    --without-http_mirror_module \
    --without-http_upstream_hash_module \
    --without-http_upstream_ip_hash_module \
    --without-http_upstream_least_conn_module \
    --without-http_upstream_random_module \
    --without-http_upstream_keepalive_module \
    --without-http_upstream_zone_module && \
    make -j"$(nproc)" && \
    cp objs/nginx /nginx && \
    strip --strip-all /nginx && \
    upx --ultra-brute /nginx -o /nginx-upx || cp /nginx /nginx-upx

################################################################################
# BUILD NGINX SSI (includes gzip)
################################################################################
FROM build-deps AS build-ssi

ARG NGINX_VERSION CFLAGS LDFLAGS

WORKDIR /build/nginx

RUN ./configure \
    --sbin-path=/nginx \
    --pid-path="/nginx.pid" \
    --lock-path="/nginx.lock" \
    --error-log-path="/dev/stdout" \
    --http-log-path="/dev/stdout" \
    --conf-path=/conf/nginx.conf \
    --prefix="/" \
    --with-cc-opt="$CFLAGS" \
    --with-ld-opt="$LDFLAGS" \
    --with-pcre \
    --with-pcre-jit \
    --with-threads \
    --with-file-aio \
    --with-http_realip_module \
    --without-select_module \
    --without-poll_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --without-http_charset_module \
    --without-http_auth_basic_module \
    --without-http_browser_module \
    --without-http_map_module \
    --without-http_autoindex_module \
    --without-http_geo_module \
    --without-http_split_clients_module \
    --without-http_userid_module \
    --without-http_empty_gif_module \
    --without-http_referer_module \
    --without-http_proxy_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    --without-http_memcached_module \
    --without-http_mirror_module \
    --without-http_upstream_hash_module \
    --without-http_upstream_ip_hash_module \
    --without-http_upstream_least_conn_module \
    --without-http_upstream_random_module \
    --without-http_upstream_keepalive_module \
    --without-http_upstream_zone_module && \
    make -j"$(nproc)" && \
    cp objs/nginx /nginx && \
    strip --strip-all /nginx && \
    upx --ultra-brute /nginx -o /nginx-upx || cp /nginx /nginx-upx

################################################################################
# BUILD NGINX SSL (includes gzip)
################################################################################
FROM build-openssl AS build-ssl

ARG NGINX_VERSION OPENSSL_VERSION CFLAGS LDFLAGS

WORKDIR /build/nginx

RUN ./configure \
    --sbin-path=/nginx \
    --pid-path="/nginx.pid" \
    --lock-path="/nginx.lock" \
    --error-log-path="/dev/stdout" \
    --http-log-path="/dev/stdout" \
    --conf-path=/conf/nginx.conf \
    --prefix="/" \
    --with-cc-opt="$CFLAGS" \
    --with-ld-opt="$LDFLAGS" \
    --with-pcre \
    --with-pcre-jit \
    --with-threads \
    --with-file-aio \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_auth_request_module \
    --without-select_module \
    --without-poll_module \
    --without-http_charset_module \
    --without-http_browser_module \
    --without-http_map_module \
    --without-http_autoindex_module \
    --without-http_geo_module \
    --without-http_split_clients_module \
    --without-http_userid_module \
    --without-http_empty_gif_module \
    --without-http_referer_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    --without-http_ssi_module \
    --without-http_memcached_module \
    --without-http_mirror_module \
    --without-http_upstream_hash_module \
    --without-http_upstream_ip_hash_module \
    --without-http_upstream_least_conn_module \
    --without-http_upstream_random_module \
    --without-http_upstream_keepalive_module \
    --without-http_upstream_zone_module && \
    make -j"$(nproc)" && \
    cp objs/nginx /nginx && \
    strip --strip-all /nginx && \
    upx --ultra-brute /nginx -o /nginx-upx || cp /nginx /nginx-upx

################################################################################
# SKELETON: a writable /tmp owned by uid 101 for the unprivileged variants.
# scratch has no shell/mkdir at runtime, so the directory must be pre-created
# here and COPY --chown'd into the final image.
################################################################################
FROM alpine:edge AS unpriv-skel
RUN mkdir -p /skel/tmp && chown 101:101 /skel/tmp && chmod 0700 /skel/tmp

################################################################################
# Minimal /etc/passwd, /etc/group
################################################################################
FROM scratch AS nginx-user

ARG NGINX_VERSION

LABEL maintainer="James Dornan <james@catch22.com>" \
      org.opencontainers.image.source="https://github.com/johnnyjoy/nginx-micro" \
      org.opencontainers.image.version="${NGINX_VERSION}"

COPY --from=build-deps /nginx.passwd /etc/passwd
COPY --from=build-deps /nginx.group /etc/group

COPY conf /conf

EXPOSE 80
# nginx treats SIGQUIT as graceful shutdown (drain in-flight connections);
# Docker's default SIGTERM is nginx "fast shutdown" and drops connections.
STOPSIGNAL SIGQUIT
CMD ["/nginx", "-g", "daemon off;"]
################################################################################
# FINAL Nginx Micro
################################################################################
FROM nginx-user AS micro

COPY --from=build-micro /nginx /nginx
################################################################################
# FINAL Nginx Micro Upx
################################################################################
FROM nginx-user AS micro-upx

COPY --from=build-micro /nginx-upx /nginx
################################################################################
# FINAL Nginx Gzip
################################################################################
FROM nginx-user AS gzip

COPY --from=build-gzip /nginx /nginx
################################################################################
# FINAL Nginx Gzip Upx
################################################################################
FROM nginx-user AS gzip-upx

COPY --from=build-gzip /nginx-upx /nginx
################################################################################
# FINAL Nginx SSI
################################################################################
FROM nginx-user AS ssi

COPY --from=build-ssi /nginx /nginx
################################################################################
# FINAL Nginx SSI Upx
################################################################################
FROM nginx-user AS ssi-upx

COPY --from=build-ssi /nginx-upx /nginx
################################################################################
# FINAL Nginx SSL
################################################################################
FROM nginx-user AS ssl

COPY --from=build-ssl /nginx /nginx

# 443/tcp for HTTP/1.1 + HTTP/2; 443/udp for HTTP/3 (QUIC).
EXPOSE 443 443/udp
################################################################################
# FINAL Nginx SSL Upx
################################################################################
FROM nginx-user AS ssl-upx

COPY --from=build-ssl /nginx-upx /nginx

# 443/tcp for HTTP/1.1 + HTTP/2; 443/udp for HTTP/3 (QUIC).
EXPOSE 443 443/udp
################################################################################
# UNPRIVILEGED base: runs as UID 101, binds high ports, writable state in /tmp.
# Reuses the SSL binary (it carries the proxy/TLS/H2/H3 modules) and only swaps
# the bundled config + ownership so the whole process tree runs rootless.
################################################################################
FROM scratch AS nginx-user-unprivileged

ARG NGINX_VERSION

LABEL maintainer="James Dornan <james@catch22.com>" \
      org.opencontainers.image.source="https://github.com/johnnyjoy/nginx-micro" \
      org.opencontainers.image.version="${NGINX_VERSION}"

COPY --from=build-deps /nginx.passwd /etc/passwd
COPY --from=build-deps /nginx.group /etc/group

# Shared mime.types / fastcgi_params, then override nginx.conf with the
# unprivileged config (no "user" directive, high ports, /tmp paths).
COPY conf /conf
COPY conf-unprivileged/nginx.conf /conf/nginx.conf

# The only writable directory in the image, owned by uid 101.
COPY --from=unpriv-skel --chown=101:101 /skel/tmp /tmp

# 8080/tcp for HTTP/1.1 + HTTP/2; non-root cannot bind ports < 1024.
EXPOSE 8080
STOPSIGNAL SIGQUIT
USER 101:101
CMD ["/nginx", "-g", "daemon off;"]
################################################################################
# FINAL Nginx SSL Unprivileged
################################################################################
FROM nginx-user-unprivileged AS ssl-unprivileged

COPY --from=build-ssl /nginx /nginx

# 8443/tcp for HTTP/1.1 + HTTP/2; 8443/udp for HTTP/3 (QUIC).
EXPOSE 8443 8443/udp
################################################################################
# FINAL Nginx SSL Unprivileged Upx
################################################################################
FROM nginx-user-unprivileged AS ssl-unprivileged-upx

COPY --from=build-ssl /nginx-upx /nginx

# 8443/tcp for HTTP/1.1 + HTTP/2; 8443/udp for HTTP/3 (QUIC).
EXPOSE 8443 8443/udp
