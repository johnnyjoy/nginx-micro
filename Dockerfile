### build stage ###
FROM alpine:edge as builder

ENV NGINX_VERSION=1.29.0

RUN echo 'http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories && \
	apk add --no-cache \
		linux-headers \
		pcre2-dev \
		pcre2-static \
		zlib-dev \
		build-base \
		gnupg && \
	apk add upx || true

# Download nginx, signature, and public key, and verify the download
RUN set -eux; \
    wget -O nginx.tar.gz "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" && \
    wget -O nginx.tar.gz.asc "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc" && \
    wget -O /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key && \
    gpg --import /tmp/nginx_signing.key && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys D6786CE303D9A9022998DC6CC8464D549AF75C0A && \
    gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz

RUN tar xvfz nginx.tar.gz && \
	cd /nginx-${NGINX_VERSION} && \
	./configure \
		--sbin-path="/nginx" \
		--pid-path="/nginx.pid" \
		--lock-path="/nginx.lock" \
		--conf-path="/conf/nginx.conf" \
		--error-log-path="/dev/stdout" \
		--http-log-path="/dev/stdout" \
		--with-cc-opt="-Os -s -fno-ident -fno-asynchronous-unwind-tables -static" \
		--with-ld-opt="-static -s" \
		--prefix="/" \
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
	time make -j $(nprocs) && \
	cp objs/nginx / && \
	strip /nginx && \
	upx --ultra-brute /nginx || true

# Build minimal /etc/passwd and /etc/group to support user nginx (optional, but recommended)
RUN echo 'nginx:x:101:101:nginx:/nonexistent:/sbin/nologin' > /etc/passwd && \
    echo 'nginx:x:101:' > /etc/group

### run stage ###
FROM scratch

COPY --from=builder /nginx /nginx
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY conf /conf

EXPOSE 80

ENTRYPOINT ["/nginx", "-g", "daemon off;"]
