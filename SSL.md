# 🚀 Quick SSL/TLS Testing with nginx-micro

**Test HTTPS with your ultra-minimal nginx-micro image on any platform in seconds.
No need for shell access in the container—everything is mounted at runtime.**

---

## 1. Generate a Self-Signed SSL Certificate

Run **on your host** (Linux/Mac/WSL/PowerShell), not inside the container:

```sh
openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
  -keyout nginx.key -out nginx.crt \
  -subj "/CN=localhost"
```

This creates two files:

* `nginx.key` (private key)
* `nginx.crt` (certificate)

---

## 2. Minimal SSL nginx.conf Example

Create a file named `nginx.conf` with:

```nginx
worker_processes  1;
error_log  /dev/stdout;
pid        /tmp/nginx.pid;

events { worker_connections  1024; }

http {
    access_log /dev/stdout;

    server {
        listen 443 ssl;
        server_name _;

        ssl_certificate     /conf/nginx.crt;
        ssl_certificate_key /conf/nginx.key;

        root /www;
        index index.html;

        location / {
            try_files $uri $uri/ =404;
        }
    }
}
```

---

## 3. Run nginx-micro with SSL

Make sure you have at least one file in your `./www` directory (e.g., `index.html`).

```sh
docker run --rm -p 8443:443 \
  -v $(pwd)/nginx.conf:/conf/nginx.conf:ro \
  -v $(pwd)/nginx.crt:/conf/nginx.crt:ro \
  -v $(pwd)/nginx.key:/conf/nginx.key:ro \
  -v $(pwd)/www:/www:ro \
  tigersmile/nginx-micro:1.29.3-ssl-upx
```

* The container listens on port 443 (exposed as 8443 on your host)
* All configs and certs are mounted read-only

---

## 4. Test the HTTPS Endpoint

### In your browser:

* Go to: [https://localhost:8443](https://localhost:8443)
* You’ll see a certificate warning (expected for self-signed). Accept/ignore to proceed.

### With `curl`:

```sh
curl -k https://localhost:8443
```

> `-k` skips certificate validation (perfect for dev/test use).

---

## 5. Troubleshooting

* **Error about missing `/tmp/nginx.pid` or `/tmp/client_body_temp`?**
  Your build should have `--pid-path=/tmp/nginx.pid` and `--prefix=/tmp` in `./configure`.
  See [nginx-micro README](./README.md) for details.

* **"user" directive warning?**
  Ignore unless you’re running as root.
  If running as a non-root user, the directive is ignored.

---

## 6. Notes

* **Never use self-signed certs in production!**
  For real deployments, use certificates from a trusted CA (Let’s Encrypt, etc).

* **For HTTP/2/3:**
  See [nginx.org docs](https://nginx.org/en/docs/http/ngx_http_v2_module.html) and [QUIC/HTTP3](https://quic.nginx.org/readme.html).

---

## 7. Example: FastCGI (PHP-FPM) behind SSL

Add this to your `nginx.conf` inside the `server { ... }` block:

```nginx
location ~ \.php$ {
    fastcgi_pass   php-fpm:9000;
    fastcgi_index  index.php;
    include        fastcgi_params;
}
```

Run a `php-fpm` container in the same Docker network, and mount your site to `/www`.

---

**Ultra-minimal, blazing-fast SSL with nginx-micro—everywhere.**

---

If you hit any issues, open a GitHub issue with your error and config.
Happy hacking!
