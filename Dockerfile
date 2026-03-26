# ==========================================
# 1. 前端构建阶段 (在构建机原生架构上运行，如 arm64 或 amd64)
# ==========================================
FROM --platform=$BUILDPLATFORM oven/bun:latest AS frontend-build
WORKDIR /src/frontend
COPY frontend/package*.json ./
RUN bun install
COPY frontend/ ./
RUN bun run build

# ==========================================
# 2. Go 后端构建阶段 (同样在原生架构上运行，利用 Go 的交叉编译能力)
# ==========================================
FROM --platform=$BUILDPLATFORM golang:1.24 AS builder
WORKDIR /src

# 复制依赖文件并下载
COPY go.mod go.sum ./
RUN go env -w GOPROXY=https://proxy.golang.org
RUN go mod download

# 复制源代码
COPY . .

# 从前端阶段复制生成的静态资源（这是 go:embed 需要的）
COPY --from=frontend-build /src/frontend/dist ./frontend/dist

# 关键步骤：明确指定交叉编译目标为 ARMv7
# GOARCH=arm, GOARM=7 是编译 32位 ARMv7 的标准参数
ARG TARGETOS=linux
ARG TARGETARCH=arm
ARG TARGETVARIANT=v7
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=7 \
    go build -ldflags='-s -w' -o /out/cups-web ./cmd/server

# ==========================================
# 3. 运行阶段 (最终生成的镜像架构为 armv7)
# ==========================================
# 这里不需要 --platform，因为 docker buildx build --platform linux/arm/v7 
# 会自动让基础镜像选择正确的架构。
FROM debian:bookworm-slim AS runtime

# 安装 LibreOffice 和字体 (Debian 官方源支持 armv7)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice-core \
    libreoffice-writer \
    libreoffice-calc \
    libreoffice-impress \
    openjdk-17-jre \
    fonts-dejavu-core \
    fonts-noto-cjk \
    fonts-arphic-uming \
    fonts-arphic-ukai \
    fonts-wqy-zenhei \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户
RUN groupadd -r nonroot && useradd -r -g nonroot nonroot

# 准备 LibreOffice 运行所需的目录权限
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

# 从 builder 复制编译好的 armv7 二进制文件
COPY --from=builder /out/cups-web /cups-web

EXPOSE 8080
USER nonroot
ENTRYPOINT ["/cups-web"]
