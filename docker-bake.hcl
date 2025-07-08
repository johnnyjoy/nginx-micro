group "default" {
  targets = ["nginx-micro"]
}

target "nginx-micro" {
  context = "."
  dockerfile = "Dockerfile"
  tags = [
    "tigersmile/nginx-micro:latest",
    "tigersmile/nginx-micro:1.29.0"
  ]
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
