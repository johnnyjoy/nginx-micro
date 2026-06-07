# nginx-micro

> **Ultra-minimal, statically-linked, multi-architecture NGINX Docker images.**

A blazing-fast, container-native NGINX image—just **hundreds of kilobytes**—with no shell, no package manager, and no attack surface beyond static serving and FastCGI.
**Purpose-built** for modern container stacks, edge deployments, and anyone who wants a rock-solid, tiny HTTP server.

---

## 🚀 Supported Platforms

| Platform | Supported? | UPX-compressed Variant? | Typical Use Case                 |
| -------- | :--------: | :---------------------: | -------------------------------- |
| amd64    |      ✅     |            ✅            | Standard servers, laptops, cloud |
| arm64    |      ✅     |            ✅            | Raspberry Pi 4/5, Apple Silicon  |
| arm/v7   |      ✅     |            ✅            | Older ARM SBCs, IoT devices      |
| arm/v6   |      ✅     |            ✅            | Raspberry Pi 1/Zero, legacy ARM  |
| 386      |      ✅     |            ✅            | Legacy x86                       |
| ppc64le  |      ✅     |            ✅            | IBM Power, OpenPower             |
| s390x    |      ✅     |            ❌            | IBM Mainframe                    |
| riscv64  |      ✅     |            ❌            | Next-gen embedded/server         |

> **Note:** UPX-compressed images (`-upx` tags) are only published for platforms supported by UPX on Alpine Linux.

---

## 🏷️ Image Tags & Feature Matrix

Multiple image variants are published for different use cases.
**Choose the tag that matches your needs:**

| Tag                | Features                       | SSL/TLS | gzip | SSI | UPX-compressed | Platforms<sup>†</sup>                        | Typical Use              |
| ------------------ | ------------------------------ | :-----: | :--: | :-: | :------------: | :------------------------------------------- | ------------------------ |
| `:1.31.1`          | Minimal HTTP, FastCGI          |    ❌    |   ❌  |  ❌  |        ❌       | All supported                                | Most minimal HTTP only   |
| `:1.31.1-upx`      | Same as above (smaller binary) |    ❌    |   ❌  |  ❌  |        ✅       | `amd64`, `arm64`, `arm/v7`, `arm/v6`, `386`, `ppc64le` | Smallest HTTP only       |
| `:1.31.1-gzip`     | HTTP, FastCGI, gzip (encoding) |    ❌    |   ✅  |  ❌  |        ❌       | All supported                                | gzip-compress HTTP       |
| `:1.31.1-gzip-upx` | gzip, UPX-compressed           |    ❌    |   ✅  |  ❌  |        ✅       | UPX platforms (see above)                    | Smallest with gzip       |
| `:1.31.1-ssi`      | HTTP, FastCGI, gzip, SSI       |    ❌    |   ✅  |  ✅  |        ❌       | All supported                                | Static sites with SSI    |
| `:1.31.1-ssi-upx`  | gzip, SSI, UPX-compressed      |    ❌    |   ✅  |  ✅  |        ✅       | UPX platforms (see above)                    | Smallest with SSI        |
| `:1.31.1-ssl`      | HTTP, FastCGI, SSL/TLS, HTTP/2, HTTP/3, gzip |    ✅    |   ✅  |  ❌  |        ❌       | All supported                                | HTTPS, HTTP/2 & HTTP/3   |
| `:1.31.1-ssl-upx`  | SSL/TLS, HTTP/2, HTTP/3, gzip, UPX-compressed |    ✅    |   ✅  |  ❌  |        ✅       | UPX platforms (see above)                    | HTTPS/2/3, smallest      |

<sup>†</sup> UPX-compressed images (`-upx` tags) are **not** built for `s390x` or `riscv64`, since UPX does not support them on Alpine.

---

## 📦 How Does the Size Compare?

| Platform | Official nginx:1.31 | nginx-micro:1.31.1-upx | nginx-micro:1.31.1 |
| -------- | :-----------------: | :--------------------: | :----------------: |
| amd64    |       68.86 MB      |       **432 KB**       |       1.19 MB      |
| arm64    |       65.54 MB      |       **423 KB**       |       1.17 MB      |
| arm/v7   |       57.91 MB      |       **422 KB**       |       1.16 MB      |
| 386      |       67.31 MB      |       **448 KB**       |       1.22 MB      |
| ppc64le  |       73.34 MB      |       **457 KB**       |       1.26 MB      |
| s390x    |       63.82 MB      |          *N/A*         |       1.36 MB      |
| riscv64  |         N/A         |          *N/A*         |       1.30 MB      |

> That’s up to **160× smaller** than the official nginx images!

---

## ⚡️ Why nginx-micro?

* **FROM scratch**: No shell, no package manager, no interpreter. Zero bloat.
* **Attack surface**: *Minimized.* Static HTTP, FastCGI (for PHP), and real-IP recovery in every variant; the `-ssl` variant additionally bundles the proxy and `auth_request` modules (by popular demand) for TLS-terminating front ends.
* **Security**: GPG-verified source, statically linked, no extraneous libraries.
* **Multi-arch**: Works on virtually any Linux system—cloud, Pi, mainframe, or edge.
* **Logs to stdout/stderr**: Perfect for Docker/Kubernetes observability.
* **Plug-and-play config**: Use the included config, or mount your own.
* **Built for insecure HTTP**: Use behind any SSL-terminating reverse proxy (Caddy, Traefik, HAProxy, nginx, Cloudflare, etc.).
* **SSL/TLS, HTTP/2, HTTP/3, gzip, and SSI**: Optional tags (`-ssl`, `-gzip`, `-ssi`, and `-upx` variants) for more features. The `-ssl` tags include HTTP/2 and HTTP/3 (QUIC) support.

---

## 🛡️ Intended Use

* **NOT for direct SSL/public internet use by default!**

  * The `-ssl` tags add built-in HTTPS, but it’s still recommended to use a reverse proxy for cert management.
* *Ideal for:*

  * Static sites and health checks
  * PHP apps via FastCGI (`php-fpm`)
  * Serving assets in microservices
  * Demo, staging, CI pipelines
  * Ultra-lightweight edge deployments

---

## 🏁 Quick Start

### **Serve static files from your current directory:**

```sh
docker run --rm -p 8080:80 \
  -v $(pwd):/www \
  tigersmile/nginx-micro
```

Open [http://localhost:8080](http://localhost:8080) in your browser.

---

### **Mount your own `nginx.conf` for full control:**

```sh
docker run --rm -p 8080:80 \
  -v $(pwd)/nginx.conf:/conf/nginx.conf:ro \
  -v $(pwd)/site:/www \
  tigersmile/nginx-micro
```

---

### **Use with PHP-FPM (e.g., WordPress/Drupal):**

```yaml
# docker-compose.yml
services:
  nginx:
    image: tigersmile/nginx-micro
    ports:
      - "8080:80"
    volumes:
      - ./conf:/conf
      - ./www:/www
    depends_on:
      - php-fpm
    networks: [ web ]
  php-fpm:
    image: php:fpm
    volumes:
      - ./www:/www
    networks: [ web ]
networks:
  web:
```

---

## 📝 Default nginx.conf

```nginx
user  nginx;
worker_processes  1;

error_log  /dev/stdout;
pid        /nginx.pid;

events { worker_connections  1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format standard '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /dev/stdout standard;

    sendfile           on;
    keepalive_timeout  65;

    server {
        listen       80 default_server;
        server_name  _;

        root   /www;
        index  index.html index.php;

        location / {
            try_files $uri $uri/ =404;
        }

        # For PHP-FPM
        location ~ \.php$ {
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_param HTTP_PROXY "";
            fastcgi_pass   php-fpm:9000;
            fastcgi_index  index.php;
            include        fastcgi_params;
        }
    }
}
```

---

## 🏷️ Tag and Feature Reference

| Tag                | gzip | SSL/TLS | SSI | UPX | Description                  | Platforms     |
| ------------------ | :--: | :-----: | :-: | :-: | ---------------------------- | ------------- |
| `:1.31.1`          |   ❌  |    ❌    |  ❌  |  ❌  | Minimal HTTP only            | all           |
| `:1.31.1-upx`      |   ❌  |    ❌    |  ❌  |  ✅  | Minimal HTTP, smallest size  | upx platforms |
| `:1.31.1-gzip`     |   ✅  |    ❌    |  ❌  |  ❌  | gzip content-encoding        | all           |
| `:1.31.1-gzip-upx` |   ✅  |    ❌    |  ❌  |  ✅  | gzip, smallest size          | upx platforms |
| `:1.31.1-ssi`      |   ✅  |    ❌    |  ✅  |  ❌  | gzip, SSI                    | all           |
| `:1.31.1-ssi-upx`  |   ✅  |    ❌    |  ✅  |  ✅  | gzip, SSI, smallest size     | upx platforms |
| `:1.31.1-ssl`      |   ✅  |    ✅    |  ❌  |  ❌  | SSL/TLS, HTTP/2, HTTP/3, gzip            | all           |
| `:1.31.1-ssl-upx`  |   ✅  |    ✅    |  ❌  |  ✅  | SSL/TLS, HTTP/2, HTTP/3, gzip, smallest  | upx platforms |

**What’s a “UPX platform”?**
Currently: `amd64`, `arm64`, `arm/v7`, `arm/v6`, `386`, `ppc64le` (but not `s390x` or `riscv64`).

---

## ⚙️ What’s Included / Not Included

| Feature             | Included? | Notes                               |
| ------------------- | :-------: | ----------------------------------- |
| Static file serving |     ✅     | `/www` is default root              |
| FastCGI/PHP-FPM     |     ✅     | Use with `php-fpm` container        |
| gzip                |  *varies* | Use a `-gzip`, `-ssi`, or `-ssl` tag |
| SSL/TLS             |  *varies* | Use a `-ssl` tag                    |
| HTTP/2              |  *varies* | Included in `-ssl` tags             |
| HTTP/3 (QUIC)       |  *varies* | Included in `-ssl` tags             |
| Proxy/Upstream      |  *varies* | Included in `-ssl` tags (by popular demand) |
| realip              |     ✅     | Recover client IP behind a reverse proxy |
| auth_request        |  *varies* | Included in `-ssl` tags                 |
| SSI                 |  *varies* | Use a `-ssi` tag                    |
| autoindex           |     ❌     | Not included                        |
| Custom config       |     ✅     | Mount `/conf/nginx.conf`            |
| Logs to stdout      |     ✅     | Container-native                    |
| GPG-verified build  |     ✅     | Verified source integrity           |

---

## 🔒 Security Notes

* **Worker processes drop to the unprivileged `nginx` user (uid 101).**

  * The image ships `/etc/passwd` and `/etc/group` defining `nginx` (uid/gid 101), and the default config uses `user nginx;`.
  * The master process starts as root (the container's default user) so it can bind port 80/443, then nginx itself drops the workers to `nginx` — this is standard nginx behavior, not a container `USER` override.
  * To run the **entire** process tree (including the master) as non-root, pass `--user 101:101`. In that case you must listen on an unprivileged port (≥1024), since a non-root master cannot bind 80/443.
* No shell or package manager—cannot be “container escaped” by shell exploits.
* Statically linked, no interpreters, minimal attack surface.

> **Note:**
> Because the master runs as root by default, binding privileged ports (80/443) works out of the box. If you front this image with a reverse proxy, prefer running fully unprivileged with `--user 101:101` on a high port.

---

## 🏗️ Building Yourself

Requires Docker with Buildx and QEMU (for multi-arch):

```sh
docker buildx bake
```

*(Uses included `docker-bake.hcl` for all architectures and tags.)*

---

## 📄 License

Released under the [MIT License](./LICENSE). © 2025 James Dornan.

---

## 🤝 Contribute & Contact

* Issues and PRs welcome! [GitHub repo](https://github.com/tigersmile/nginx-micro)
* Suggestions for features or new use-cases? Open an issue!
* Show off your usage or share feedback—we want to hear from you!

---

## 📣 Why not just use the official nginx image?

* **Ours is up to 160× smaller.**
* **No shell, no bloat, no hidden dependencies.**
* **Perfect for CI, health checks, microservices, edge, and cloud.**

---

**Ultra-minimal nginx—secure, fast, tiny, everywhere.**

---

*If you find this useful, star the repo, tell a friend, and help spread the word!*
*(Project by [johnnyjoy](https://github.com/johnnyjoy).)*
