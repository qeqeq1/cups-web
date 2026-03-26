# 1. 前端构建阶段：强制使用构建机器的原生架构 (通常是 arm64 或 amd64)
# 这样 Bun 就能正常运行，因为它不需要在目标架构上编译代码
FROM --platform=$BUILDPLATFORM oven/bun AS frontend-build
WORKDIR /src/frontend
COPY frontend/package*.json ./
RUN bun install
COPY frontend/ ./
RUN bun run build

# 2. 最终运行阶段：这是你需要的 armv7 镜像
# 注意：这一阶段的镜像（如 alpine, debian, nginx）必须支持 armv7
FROM --platform=linux/arm/v7 debian:bookworm-slim 
# 或者使用 nginx:alpine 等支持 armv7 的镜像

WORKDIR /app

# 从前端构建阶段复制编译好的静态文件
COPY --from=frontend-build /src/frontend/dist ./dist

# ... 其他安装步骤 ...
# 注意：如果你在这里需要运行 bun，那是不行的，因为 bun 不支持 armv7。
# 如果你只是运行 python/node/cups 等支持 armv7 的程序，则没问题。
WORKDIR /src/frontend
COPY frontend/package*.json ./
RUN bun install
COPY frontend ./
RUN bun run build

FROM golang:1.24 AS builder
WORKDIR /src

# copy go modules and source
COPY go.mod go.sum ./
RUN go env -w GOPROXY=https://proxy.golang.org
RUN go mod download
COPY . .
# Copy built frontend assets into expected location for go:embed
COPY --from=frontend-build /src/frontend/dist ./frontend/dist

# Build the Go binary (frontend must be built before this step in CI/local)
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /out/cups-web ./cmd/server

FROM debian:bookworm-slim AS runtime

# Install LibreOffice (headless conversion) and minimal fonts/certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice-core libreoffice-writer libreoffice-calc libreoffice-impress openjdk-17-jre \
    fonts-dejavu-core fonts-noto-cjk fonts-arphic-uming fonts-arphic-ukai fonts-wqy-zenhei \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Create a non-root user for running the service
RUN groupadd -r nonroot && useradd -r -g nonroot nonroot

RUN mkdir -p \
    /home/nonroot/.cache/dconf \
    /home/nonroot/.config/libreoffice \
    /home/nonroot/.local/share/libreoffice \
  && chown -R nonroot:nonroot /home/nonroot/ \
  && chmod -R 755 /home/nonroot/ \
  && chmod 700 /home/nonroot/.cache/dconf

ENV DCONF_USER_CONFIG_DIR=/home/nonroot/.config/dconf
ENV HOME=/home/nonroot
ENV XDG_CACHE_HOME=/home/nonroot/.cache

COPY --from=builder /out/cups-web /cups-web
EXPOSE 8080
USER nonroot
ENTRYPOINT ["/cups-web"]
