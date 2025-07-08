# nginx-micro

> **Ultra-minimal, statically-linked, multi-architecture NGINX Docker image.**

A blazing-fast, container-native NGINX image—just **hundreds of kilobytes**—with no shell, no package manager, and no attack surface beyond static serving and FastCGI.
**Purpose-built** for modern container stacks, edge deployments, and anyone who wants a rock-solid, tiny HTTP server.

---

## 🚀 Supported Platforms

| Platform | Supported? | Typical Use Case                 |
| -------- | :--------: | -------------------------------- |
| amd64    |      ✅     | Standard servers, laptops, cloud |
| arm64    |      ✅     | Raspberry Pi 4/5, Apple Silicon  |
| arm/v7   |      ✅     | Older ARM SBCs, IoT devices      |
| 386      |      ✅     | Legacy x86                       |
| ppc64le  |      ✅     | IBM Power, OpenPower             |
| s390x    |      ✅     | IBM Mainframe                    |
| riscv64  |      ✅     | Next-gen embedded/server         |

---

## 📦 How Does the Size Compare?

| Platform | Official nginx:1.29 | nginx-micro |
| -------- | :-----------------: | :---------: |
| amd64    |       68.86 MB      |  **432 KB** |
| arm64    |       65.54 MB      |  **423 KB** |
| arm/v7   |       57.91 MB      |  **422 KB** |
| 386      |       67.31 MB      |  **448 KB** |
| ppc64le  |       73.34 MB      |  **457 KB** |
| s390x    |       63.82 MB      |  **602 KB** |
| riscv64  |         N/A         |  **593 KB** |

> That’s up to **160× smaller** than the official nginx images!

---

## ⚡️ Why nginx-micro?

* **FROM scratch**: No shell, no package manager, no interpreter. Zero bloat.
* **Attack surface**: *Minimized.* Only HTTP and FastCGI (for PHP) are supported.
* **Security**: GPG-verified source, no extraneous libraries.
* **Multi-arch**: Works on virtually any Linux system, cloud, Pi, or even mainframe.
* **Logs to stdout/stderr**: Perfect for Docker/Kubernetes observability.
* **Plug-and-play config**: Use the included config, or mount your own.
* **Built for insecure HTTP**: Use behind any SSL-terminating reverse proxy (Caddy, Traefik, HAProxy, nginx, Cloudflare, etc.).

---

## 🛡️ Intended Use

* **NOT for direct SSL/public internet use!**
* *Deploy behind an SSL reverse proxy or load balancer.*
* *Ideal for:*

  * Static sites
  * PHP apps (WordPress, Drupal, Laravel, etc. via FastCGI)
  * Health checks
  * Serving assets in microservices
  * Demo/staging/CI

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
version: "3"
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
error_log  /dev/stdout warn;
pid        /nginx.pid;

events { worker_connections  1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;
    access_log    /dev/stdout;

    sendfile      on;
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

## ⚙️ What’s Included / Not Included

| Feature              | Included? | Notes                               |
| -------------------- | :-------: | ----------------------------------- |
| Static file serving  |     ✅     | `/www` is default root              |
| FastCGI/PHP-FPM      |     ✅     | Use with `php-fpm` container        |
| SSL/TLS              |     ❌     | Use a reverse proxy for SSL         |
| Proxy/Upstream       |     ❌     | Not included (smaller, more secure) |
| gzip, SSI, autoindex |     ❌     | Not included                        |
| Custom config        |     ✅     | Mount `/conf/nginx.conf`            |
| Logs to stdout       |     ✅     | Container-native                    |
| GPG-verified build   |     ✅     | Verified source integrity           |

---

## 🔒 Security Notes

* **Runs as root** (needed for port 80 in containers), but worker processes run as `nginx` user by default.
* No shell or package manager—can’t be “container escaped” by shell exploits.
* No writable filesystem, no interpreters.
* To run as non-root:

  1. Change `listen` to a high port (e.g., 8080) in your config.
  2. Start with `--user nginx` or add `USER nginx` to your own Dockerfile.

---

## 🏗️ Building Yourself

Requires Docker with Buildx and QEMU (for multi-arch):

```sh
docker buildx bake
```

*(Uses included `docker-bake.hcl` for all architectures.)*

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
