# syntax=docker/dockerfile:1

################################################################################
# GLOBAL BUILD ARGS
################################################################################

ARG NGINX_VERSION=1.29.0
ARG OPENSSL_VERSION=3.5.0

ARG CFLAGS="-flto -fmerge-all-constants -fno-unwind-tables -fvisibility=hidden -fuse-linker-plugin -Wimplicit -Os -s -ffunction-sections -fdata-sections -fno-ident -fno-asynchronous-unwind-tables -static -Wno-cast-function-type -Wno-implicit-function-declaration"
ARG LDFLAGS="-flto -fuse-linker-plugin -static -s -Wl,--gc-sections"

################################################################################
# FETCH: download/verify nginx and openssl
################################################################################
FROM alpine:edge AS fetch

ARG NGINX_VERSION
ARG OPENSSL_VERSION

RUN apk add --no-cache wget tar gnupg

WORKDIR /build

# OpenSSL
ARG OPENSSL_CHECKSUM="344d0a79f1a9b08029b0744e2cc401a43f9c90acd1044d09a530b4885a8e9fc0"
RUN wget -O openssl.tar.gz "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" && \
    echo "${OPENSSL_CHECKSUM} openssl.tar.gz" | sha256sum -c - && \
    mkdir openssl && \
    tar xzf openssl.tar.gz -C openssl --strip-components=1

WORKDIR /build

# nginx
RUN set -eux; \
    wget -O nginx.tar.gz "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" && \
    wget -O nginx.tar.gz.asc "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc" && \
    wget -O /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key && \
    gpg --import /tmp/nginx_signing.key && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys D6786CE303D9A9022998DC6CC8464D549AF75C0A && \
    gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz && \
    mkdir nginx && \
    tar tvfz nginx.tar.gz && \
    tar xvzf nginx.tar.gz -C nginx --strip-components=1


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
      pcre2-dev pcre2-static zlib-dev zlib-static build-base perl

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

RUN case "$TARGETPLATFORM" in \
      "linux/amd64")   CONF=linux-x86_64 ;;  \
      "linux/386")     CONF=linux-x86 ;;     \
      "linux/arm/v6")  CONF=linux-armv4 ;;   \
      "linux/arm/v7")  CONF=linux-armv4 ;;   \
      "linux/arm64")   CONF=linux-aarch64 ;; \
      "linux/ppc64le") CONF=linux-ppc64le ;; \
      "linux/s390x")   CONF=linux64-s390x ;; \
      "linux/riscv64") CONF=linux64-riscv64 ;; \
      *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac && \
    echo "Configuring for $CONF" && \
    ./Configure ${CONF} \
        --prefix=/usr \
        no-cms \
        no-md2 \
        no-md4 \
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
        no-poly1305 \
        no-chacha \
        no-shared \
        no-tests \
        no-ssl3 \
        no-ssl3-method \
        no-weak-ssl-ciphers \
        no-comp \
        no-zlib \
        no-dynamic-engine \
        no-engine \
        no-dso \
        no-asm \
        no-async \
        no-filenames \
        no-docs \
        no-deprecated \
        no-apps && \
    make install_sw

################################################################################
# BUILD NGINX Micro (no gzip, no ssl)
################################################################################
FROM build-deps AS build-micro

ARG NGINX_VERSION CFLAGS LDFLAGS

WORKDIR /build/nginx

RUN ./configure \
    --sbin-path=/nginx \
    --conf-path=/conf/nginx.conf \
    --with-cc-opt="$CFLAGS" \
    --with-ld-opt="$LDFLAGS" \
    --with-pcre \
    --with-threads \
    --with-file-aio \
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
    make && \
    cp objs/nginx /nginx && \
    upx --ultra-brute /nginx -o /nginx-upx || cp /nginx /nginx-upx

################################################################################
# BUILD NGINX Gzip (no SSL)
################################################################################
FROM build-deps AS build-gzip
 
ARG NGINX_VERSION CFLAGS LDFLAGS

WORKDIR /build/nginx

RUN ./configure \
    --sbin-path=/nginx \
    --conf-path=/conf/nginx.conf \
    --with-cc-opt="$CFLAGS" \
    --with-ld-opt="$LDFLAGS" \
    --with-pcre \
    --with-threads \
    --with-file-aio \
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
    make && \
    cp objs/nginx /nginx && \
    upx --ultra-brute /nginx -o /nginx-upx || cp /nginx /nginx-upx

################################################################################
# BUILD NGINX SSL (includes gzip)
################################################################################
FROM build-openssl AS build-ssl

ARG NGINX_VERSION OPENSSL_VERSION CFLAGS LDFLAGS

WORKDIR /build/nginx

RUN ./configure \
    --sbin-path=/nginx \
    --conf-path=/conf/nginx.conf \
    --with-cc-opt="$CFLAGS" \
    --with-ld-opt="$LDFLAGS" \
    --with-pcre \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
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
    --without-http_memcached_module \
    --without-http_mirror_module \
    --without-http_upstream_hash_module \
    --without-http_upstream_ip_hash_module \
    --without-http_upstream_least_conn_module \
    --without-http_upstream_random_module \
    --without-http_upstream_keepalive_module \
    --without-http_upstream_zone_module && \
    make && \
    cp objs/nginx /nginx && \
    upx --ultra-brute /nginx -o /nginx-upx || cp /nginx /nginx-upx

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

USER 101:101

EXPOSE 80
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
# FINAL Nginx SSL
################################################################################
FROM nginx-user AS ssl

COPY --from=build-ssl /nginx /nginx

EXPOSE 443
################################################################################
# FINAL Nginx SSL Upx
################################################################################
FROM nginx-user AS ssl-upx

COPY --from=build-ssl /nginx-upx /nginx

EXPOSE 443
