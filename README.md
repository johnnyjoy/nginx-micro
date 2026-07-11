# nginx-micro

Ultra-minimal, statically linked, multi-architecture NGINX container images—typically **hundreds of kilobytes** compressed, built `FROM scratch` with no shell and no package manager.

Designed for static sites, health checks, sidecars, and TLS-terminating front ends where image size and attack surface matter.

---

## Supported platforms

| Platform | Images | UPX (`-upx` tags) | Typical use |
| -------- | :----: | :-----------------: | ----------- |
| amd64    |   ✅   |         ✅          | Servers, cloud, laptops |
| arm64    |   ✅   |         ✅          | Apple Silicon, Pi 4/5 |
| arm/v7   |   ✅   |         ✅          | Older ARM boards, IoT |
| arm/v6   |   ✅   |         ✅          | Pi 1/Zero, legacy ARM |
| 386      |   ✅   |         ✅          | Legacy x86 |
| ppc64le  |   ✅   |         ✅          | IBM Power |
| s390x    |   ✅   |         ❌          | IBM Z |
| riscv64  |   ✅   |         ❌          | RISC-V |

UPX-compressed tags are not published for `s390x` or `riscv64` (UPX unavailable on Alpine for those platforms).

---

## Image tags

Versioned tags use the NGINX release (e.g. `1.31.2`). Rolling aliases are also published: `latest`, `upx`, `gzip`, `ssl`, `ssl-unprivileged`, and corresponding `-upx` names.

| Tag | gzip | SSL/TLS | SSI | UPX | Platforms | Summary |
| --- | :--: | :-----: | :-: | :-: | --------- | ------- |
| `:1.31.2` / `:latest` | ❌ | ❌ | ❌ | ❌ | all | Smallest HTTP + FastCGI |
| `:1.31.2-upx` / `:upx` | ❌ | ❌ | ❌ | ✅ | UPX platforms† | Same, smaller binary |
| `:1.31.2-gzip` / `:gzip` | ✅ | ❌ | ❌ | ❌ | all | gzip content-encoding |
| `:1.31.2-gzip-upx` / `:gzip-upx` | ✅ | ❌ | ❌ | ✅ | UPX platforms† | gzip, smaller binary |
| `:1.31.2-ssi` / `:ssi` | ✅ | ❌ | ✅ | ❌ | all | gzip + Server Side Includes |
| `:1.31.2-ssi-upx` / `:ssi-upx` | ✅ | ❌ | ✅ | ✅ | UPX platforms† | SSI, smaller binary |
| `:1.31.2-ssl` / `:ssl` | ✅ | ✅ | ❌ | ❌ | all | TLS, HTTP/2 & HTTP/3 modules, proxy, auth_request |
| `:1.31.2-ssl-upx` / `:ssl-upx` | ✅ | ✅ | ❌ | ✅ | UPX platforms† | Same, smaller binary |
| `:1.31.2-ssl-unprivileged` / `:ssl-unprivileged` | ✅ | ✅ | ❌ | ❌ | all | Rootless `-ssl` (UID 101, ports 8080/8443) |
| `:1.31.2-ssl-unprivileged-upx` / `:ssl-unprivileged-upx` | ✅ | ✅ | ❌ | ✅ | UPX platforms† | Rootless, smaller binary |

† UPX platforms: `amd64`, `arm64`, `arm/v7`, `arm/v6`, `386`, `ppc64le`.

**Every variant** includes static file serving, FastCGI (for PHP-FPM), and the realip module. The `-ssl` and `-ssl-unprivileged` tags add TLS, HTTP/2 and HTTP/3 (QUIC) modules, gzip, reverse proxy, and auth_request. SSI requires an `-ssi` tag.

**Rootless (`-ssl-unprivileged`):** the full process tree runs as UID/GID 101. Non-root processes cannot bind ports below 1024, so use **8080** (HTTP) and **8443** (HTTPS/QUIC) inside the container—map with e.g. `-p 80:8080 -p 443:8443`. Writable runtime state (`pid`, temp paths) belongs under `/tmp`. Do not use a `user` directive. See [conf-unprivileged/nginx.conf](./conf-unprivileged/nginx.conf) for the bundled layout.

---

## Size comparison

Compressed pull sizes from Docker Hub (measured on the **1.31.1** release; **1.31.2** is expected to be similar until remeasured after publish):

| Platform | Official `nginx:1.31.1` | `nginx-micro:1.31.1-upx` | `nginx-micro:1.31.1` |
| -------- | :-------------------: | :----------------------: | :------------------: |
| amd64    | 60.18 MB | **462.89 KB** | 589.77 KB |
| arm64    | 58.56 MB | **443.15 KB** | 603.78 KB |
| arm/v7   | 50.03 MB | **449.94 KB** | 531.84 KB |
| 386      | 60.53 MB | **477.52 KB** | 608.38 KB |
| ppc64le  | 64.11 MB | **498 KB** | 656.53 KB |
| s390x    | 57.84 MB | *N/A* | 646.7 KB |
| riscv64  | 55.1 MB | *N/A* | 601.95 KB |

Compared to official `nginx:1.31.1`, the UPX image is **up to 148× smaller** on amd64 (ratio varies by platform and variant). As a secondary baseline, `nginx:1.31.1-alpine-slim` is about 4.76–5.82 MB compressed; `nginx-micro` is roughly **7–11× smaller** than alpine-slim depending on platform.

---

## Quick start

The bundled default config includes a PHP-FPM upstream. For **static files only**, mount a minimal config (below). Image reference: `tigersmile/nginx-micro` on Docker Hub.

### Static HTTP

Save as `nginx-static.conf`:

```nginx
worker_processes 1;
error_log /dev/stdout;
pid /nginx.pid;
events { worker_connections 1024; }
http {
    access_log /dev/stdout;
    server {
        listen 80;
        root /www;
        index index.html;
        location / { try_files $uri $uri/ /index.html; }
    }
}
```

```sh
docker run --rm -p 8080:80 \
  -v "$(pwd)/nginx-static.conf:/conf/nginx.conf:ro" \
  -v "$(pwd):/www:ro" \
  tigersmile/nginx-micro:latest
```

Open [http://localhost:8080](http://localhost:8080).

### Custom config (any variant)

```sh
docker run --rm -p 8080:80 \
  -v "$(pwd)/nginx.conf:/conf/nginx.conf:ro" \
  -v "$(pwd)/site:/www:ro" \
  tigersmile/nginx-micro:latest
```

### HTTPS (`-ssl` tags)

Generate a self-signed certificate on the host, then mount config and certs. Full walkthrough: **[SSL.md](./SSL.md)**.

```sh
openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
  -keyout nginx.key -out nginx.crt -subj "/CN=localhost"

docker run --rm -p 8443:443 \
  -v "$(pwd)/nginx-ssl.conf:/conf/nginx.conf:ro" \
  -v "$(pwd)/nginx.crt:/conf/nginx.crt:ro" \
  -v "$(pwd)/nginx.key:/conf/nginx.key:ro" \
  -v "$(pwd)/www:/www:ro" \
  tigersmile/nginx-micro:ssl
```

For production TLS, we still recommend a reverse proxy or cert manager for renewal and policy; the `-ssl` tags are for when you want TLS inside the container.

### Rootless HTTP (`-ssl-unprivileged`)

Use the layout from [conf-unprivileged/nginx.conf](./conf-unprivileged/nginx.conf) (HTTP on 8080). Copy or adapt it locally:

```sh
docker run --rm \
  -p 8080:8080 \
  -v "$(pwd)/conf-unprivileged/nginx.conf:/conf/nginx.conf:ro" \
  -v "$(pwd)/www:/www:ro" \
  tigersmile/nginx-micro:ssl-unprivileged
```

Add `listen 8443 ssl` and certificate paths for HTTPS on 8443 (see [SSL.md](./SSL.md)); map host 443 to 8443.

### Rootless + read-only root filesystem

Proven layout: writable `/tmp` via tmpfs with mode `1777` so UID 101 can write pid and temp files.

```sh
docker run --rm \
  --read-only \
  --tmpfs /tmp:rw,mode=1777 \
  -p 8080:8080 \
  -v "$(pwd)/conf-unprivileged/nginx.conf:/conf/nginx.conf:ro" \
  -v "$(pwd)/www:/www:ro" \
  tigersmile/nginx-micro:ssl-unprivileged
```

### PHP-FPM (Compose)

The default bundled config expects a `php-fpm` service on the Docker network:

```yaml
services:
  nginx:
    image: tigersmile/nginx-micro:latest
    ports:
      - "8080:80"
    volumes:
      - ./conf:/conf
      - ./www:/www
    depends_on:
      - php-fpm
    networks: [web]
  php-fpm:
    image: php:fpm
    volumes:
      - ./www:/www
    networks: [web]
networks:
  web:
```

### Rootless + read-only (Compose)

```yaml
services:
  nginx:
    image: tigersmile/nginx-micro:ssl-unprivileged
    read_only: true
    tmpfs:
      - /tmp:rw,mode=1777
    ports:
      - "8080:8080"
    volumes:
      - ./conf-unprivileged/nginx.conf:/conf/nginx.conf:ro
      - ./www:/www:ro
```

---

## Verification

After building or pulling images, run runtime checks locally:

```sh
./scripts/verify-images              # all variants (auto-detects local or Hub tags)
./scripts/verify-images --variant ssl
./scripts/verify-images --help
```

On each check-in, CI compiles every variant on eight platforms, then runs `verify-images` per variant on `linux/amd64`. Current tentpoles include: config syntax, process start, HTTP (or HTTPS for `-ssl` tags), gzip and SSI where applicable, unprivileged UID 101, and read-only unprivileged with tmpfs.

Not yet covered by automated runtime tests: HTTP/2 and HTTP/3 negotiation, FastCGI with a live php-fpm, image size ratios, and per-platform runtime beyond amd64. Those modules are compiled into `-ssl` tags; see [SSL.md](./SSL.md) for manual HTTPS testing.

---

## Default bundled `nginx.conf`

Privileged tags ship [conf/nginx.conf](./conf/nginx.conf): master starts as root (container default), workers run as `nginx` (UID 101), pid at `/nginx.pid`. Unprivileged tags ship [conf-unprivileged/nginx.conf](./conf-unprivileged/nginx.conf) with pid and temp paths under `/tmp`.

```nginx
user  nginx;
worker_processes  1;
error_log  /dev/stdout;
pid        /nginx.pid;
# … see conf/nginx.conf for the full file (static root, PHP-FPM location, stdout logs)
```

Mount your own file at `/conf/nginx.conf` to replace it entirely.

---

## Design notes

| Topic | Detail |
| ----- | ------ |
| Base image | `FROM scratch` — no shell, no package manager |
| Source | GPG-verified nginx (and OpenSSL on `-ssl` builds) at build time |
| Logs | Access and error logs to stdout/stderr |
| HTTP only by default | Well suited behind Traefik, Caddy, cloud load balancers, etc. |
| `-ssl` tags | TLS termination inside the container when you mount certs and config |
| autoindex | Not included |
| Multi-arch | Built via `docker-bake.hcl`; runtime verify currently amd64-only |

---

## Security

- **Standard tags:** nginx master runs as root so it can bind 80/443; workers drop to UID 101 (`user nginx` in config). This is normal nginx behavior inside the container.
- **`-ssl-unprivileged` tags:** entire tree runs as UID 101; use high ports and `/tmp` for writable paths.
- **Reduced attack surface:** no shell or interpreter in the image; static binary only. Mount read-only configs and content where possible.

---

## Build locally

```sh
./build_all                          # tags nginx-micro:* on this machine
docker buildx bake                 # multi-arch per docker-bake.hcl
./scripts/verify-images              # after images exist
```

Requires Docker Buildx; QEMU for cross-platform builds.

---

## License

[MIT License](./LICENSE). © 2025 James Dornan.

---

## Community

Issues and pull requests are welcome on [GitHub](https://github.com/johnnyjoy/nginx-micro). If nginx-micro helps your project, a star is appreciated.

---

## Why not the official nginx image?

- **Up to 148× smaller** than official `nginx:1.31.1` (UPX variant, platform-dependent; sizes from the 1.31.1 Hub snapshot).
- Minimal runtime: no distribution packages, no shell.
- A good fit for CI, health checks, microservices, and edge deployments where every megabyte counts.

*Project by [johnnyjoy](https://github.com/johnnyjoy).*
