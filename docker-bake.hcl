variable "NGINX_VERSION" {
  default = "1.29.0"
}

group "default" {
  targets = ["nginx-micro"]
}

target "nginx-micro" {
  context = "."
  dockerfile = "Dockerfile"
  tags = [
    "tigersmile/nginx-micro:${NGINX_VERSION}",
    "tigersmile/nginx-micro:latest"
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
  platforms = [
    "linux/386",
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
    "linux/s390x",
    "linux/ppc64le",
    "linux/riscv64"
  ]
  output = ["type=registry"]
}
