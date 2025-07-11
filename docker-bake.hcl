variable "NGINX_VERSION" {
  default = "1.29.0"
}

# UPX-supported platforms (based on Alpine's package availability)
variable "UPX_PLATFORMS" {
  default = [
    "linux/386",
    "linux/amd64",
    "linux/arm/v6",
    "linux/arm/v7",
    "linux/arm64",
    "linux/ppc64le"
  ]
}

# All platforms you want to build for
variable "ALL_PLATFORMS" {
  default = [
    "linux/386",
    "linux/amd64",
    "linux/arm/v6",
    "linux/arm/v7",
    "linux/arm64",
    "linux/ppc64le",
    "linux/s390x",
    "linux/riscv64"
  ]
}

group "default" {
  targets = [
    "nginx-micro",
    "nginx-micro-upx",
    "nginx-gzip",
    "nginx-gzip-upx",
    "nginx-ssl",
    "nginx-ssl-upx"
  ]
}

target "nginx-micro" {
  context = "."
  dockerfile = "Dockerfile"
  target = "micro"
  tags = [
    "tigersmile/nginx-micro:${NGINX_VERSION}",
    "tigersmile/nginx-micro:latest",
    "ghcr.io/johnnyjoy/nginx-micro:${NGINX_VERSION}",
    "ghcr.io/johnnyjoy/nginx-micro:latest"
  ]
  cache-from = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  cache-to = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  args = {
    "NGINX_VERSION" = "${NGINX_VERSION}"
  }
  platforms = "${ALL_PLATFORMS}"
}

target "nginx-micro-upx" {
  context = "."
  dockerfile = "Dockerfile"
  target = "micro-upx"
  tags = [
    "tigersmile/nginx-micro:${NGINX_VERSION}-upx",
    "tigersmile/nginx-micro:upx",
    "ghcr.io/johnnyjoy/nginx-micro:${NGINX_VERSION}-upx",
    "ghcr.io/johnnyjoy/nginx-micro:upx"
  ]
  cache-from = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  cache-to = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  args = {
    "NGINX_VERSION" = "${NGINX_VERSION}"
  }
  platforms = "${UPX_PLATFORMS}"
}

target "nginx-gzip" {
  context = "."
  dockerfile = "Dockerfile"
  target = "gzip"
  tags = [
    "tigersmile/nginx-micro:${NGINX_VERSION}-gzip",
    "tigersmile/nginx-micro:gzip",
    "ghcr.io/johnnyjoy/nginx-micro:${NGINX_VERSION}-gzip",
    "ghcr.io/johnnyjoy/nginx-micro:gzip"
  ]
  cache-from = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  cache-to = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  args = {
    "NGINX_VERSION" = "${NGINX_VERSION}"
  }
  platforms = "${ALL_PLATFORMS}"
}

target "nginx-gzip-upx" {
  context = "."
  dockerfile = "Dockerfile"
  target = "gzip-upx"
  tags = [
    "tigersmile/nginx-micro:${NGINX_VERSION}-gzip-upx",
    "tigersmile/nginx-micro:gzip-upx",
    "ghcr.io/johnnyjoy/nginx-micro:${NGINX_VERSION}-gzip-upx",
    "ghcr.io/johnnyjoy/nginx-micro:gzip-upx"
  ]
  cache-from = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  cache-to = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  args = {
    "NGINX_VERSION" = "${NGINX_VERSION}"
  }
  platforms = "${UPX_PLATFORMS}"
}

target "nginx-ssl" {
  context = "."
  dockerfile = "Dockerfile"
  target = "ssl"
  tags = [
    "tigersmile/nginx-micro:${NGINX_VERSION}-ssl",
    "tigersmile/nginx-micro:ssl",
    "ghcr.io/johnnyjoy/nginx-micro:${NGINX_VERSION}-ssl",
    "ghcr.io/johnnyjoy/nginx-micro:ssl"
  ]
  cache-from = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  cache-to = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  args = {
    "NGINX_VERSION" = "${NGINX_VERSION}"
  }
  platforms = "${ALL_PLATFORMS}"
}

target "nginx-ssl-upx" {
  context = "."
  dockerfile = "Dockerfile"
  target = "ssl-upx"
  tags = [
    "tigersmile/nginx-micro:${NGINX_VERSION}-ssl-upx",
    "tigersmile/nginx-micro:ssl-upx",
    "ghcr.io/johnnyjoy/nginx-micro:${NGINX_VERSION}-ssl-upx",
    "ghcr.io/johnnyjoy/nginx-micro:ssl-upx"
  ]
  cache-from = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  cache-to = [
    {
      type = "registry",
      ref = "tigersmile/nginx-micro-cache"
    }
  ]
  args = {
    "NGINX_VERSION" = "${NGINX_VERSION}"
  }
  platforms = "${UPX_PLATFORMS}"
}
