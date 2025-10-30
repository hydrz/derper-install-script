#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="2.1.0"

# Default values
DERPER_PORT="443"
DERPER_HTTP_PORT="80"
DERPER_STUN_PORT="3478"
DERPER_HOSTNAME=""
DERPER_CERTMODE="letsencrypt"
DERPER_WORKDIR="/var/lib/derper"
DERPER_STUN="true"
DERPER_VERIFY_CLIENTS="false"
DERPER_EXTRA_ARGS=""
USE_ALIYUN_INTERNAL="false"
INSTALL_TAILSCALED="false"
TAILSCALE_VERSION="latest"
DERPER_VERSION="latest"
UNINSTALL_MODE="false"
KEEP_DATA="false"

# Check if output is to a terminal
if [ -t 1 ]; then
	# Terminal output - use colors
	USE_COLOR=true
else
	# Pipe or redirect - no colors
	USE_COLOR=false
	RED=''
	GREEN=''
	YELLOW=''
	BLUE=''
	NC=''
fi

# Print colored message
print_info() {
	if [ "$USE_COLOR" = true ]; then
		echo -e "${GREEN}[INFO]${NC} $1"
	else
		echo "[INFO] $1"
	fi
}

print_warn() {
	if [ "$USE_COLOR" = true ]; then
		echo -e "${YELLOW}[WARN]${NC} $1"
	else
		echo "[WARN] $1"
	fi
}

print_error() {
	if [ "$USE_COLOR" = true ]; then
		echo -e "${RED}[ERROR]${NC} $1"
	else
		echo "[ERROR] $1"
	fi
}

print_step() {
	if [ "$USE_COLOR" = true ]; then
		echo -e "${BLUE}[STEP]${NC} $1"
	else
		echo "[STEP] $1"
	fi
}

# Print colored line
print_line() {
	local color=$1
	local text=$2
	if [ "$USE_COLOR" = true ]; then
		echo -e "${color}${text}${NC}"
	else
		echo "$text"
	fi
}

# Show banner
show_banner() {
	cat <<"EOF"
    ____                              ____           __        ____
   / __ \___  _________  ___  _____  /  _/___  _____/ /_____ _/ / /__  _____
  / / / / _ \/ ___/ __ \/ _ \/ ___/  / // __ \/ ___/ __/ __ `/ / / _ \/ ___/
 / /_/ /  __/ /  / /_/ /  __/ /    _/ // / / (__  ) /_/ /_/ / / /  __/ /
/_____/\___/_/  / .___/\___/_/    /___/_/ /_/____/\__/\__,_/_/_/\___/_/
               /_/

EOF
	print_line "$GREEN" "Derper 安装脚本 v${VERSION}"
	print_line "$BLUE" "https://github.com/hydrz/derper-install-script"
	echo ""
}

# Show usage
usage() {
	cat <<EOF
使用方法: curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - [选项]

一键安装 Tailscale DERP 服务器的自动化脚本。

选项:
    -h, --help                  显示帮助信息
    --port PORT                 HTTPS 监听端口 (默认: 443)
    --http-port PORT            HTTP 端口 (默认: 80)
    --stun-port PORT            STUN UDP 端口 (默认: 3478)
    --hostname HOSTNAME         LetsEncrypt 域名 (必需)
    --workdir DIR               工作目录 (默认: /var/lib/derper)
    --certmode MODE             证书模式: letsencrypt 或 manual (默认: letsencrypt)
    --no-stun                   禁用 STUN 服务器
    --verify-clients            启用客户端验证（需要本地 tailscaled）
    --extra-args "ARGS"         传递给 derper 的额外参数
    --aliyun-internal           使用阿里云 ECS 内网镜像
    --install-tailscaled        同时安装 tailscaled
    -v VER                      指定版本 (默认: latest)
    --uninstall                 卸载服务
    --keep-data                 卸载时保留数据

快速开始:
    # 基础安装
    curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --hostname derp.example.com

    # 阿里云 ECS 安装
    curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --hostname derp.example.com --aliyun-internal

    # 安装指定版本
    curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --hostname derp.example.com -v 1.90.4

    # 同时安装 tailscaled
    curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --hostname derp.example.com --install-tailscaled

    # 卸载
    curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --uninstall

本地安装:
    # 下载脚本
    wget https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh
    chmod +x install.sh

    # 运行安装
    sudo ./install.sh --hostname derp.example.com

更多信息:
    GitHub: https://github.com/hydrz/derper-install-script
    文档: https://github.com/hydrz/derper-install-script/blob/main/README.md

EOF
	exit 0
}

# Parse command line arguments
parse_args() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		-h | --help)
			usage
			;;
		--port)
			DERPER_PORT="$2"
			shift 2
			;;
		--http-port)
			DERPER_HTTP_PORT="$2"
			shift 2
			;;
		--stun-port)
			DERPER_STUN_PORT="$2"
			shift 2
			;;
		--hostname)
			DERPER_HOSTNAME="$2"
			shift 2
			;;
		--workdir)
			DERPER_WORKDIR="$2"
			shift 2
			;;
		--certmode)
			DERPER_CERTMODE="$2"
			shift 2
			;;
		--no-stun)
			DERPER_STUN="false"
			shift
			;;
		--verify-clients)
			DERPER_VERIFY_CLIENTS="true"
			shift
			;;
		--extra-args)
			DERPER_EXTRA_ARGS="$2"
			shift 2
			;;
		--aliyun-internal)
			USE_ALIYUN_INTERNAL="true"
			shift
			;;
		--install-tailscaled)
			INSTALL_TAILSCALED="true"
			shift
			;;
		-v)
			DERPER_VERSION="$2"
			TAILSCALE_VERSION="$2"
			shift 2
			;;
		--uninstall)
			UNINSTALL_MODE="true"
			shift
			;;
		--keep-data)
			KEEP_DATA="true"
			shift
			;;
		*)
			print_error "未知选项: $1"
			echo ""
			usage
			;;
		esac
	done
}

# Check if running as root
check_root() {
	if [[ $EUID -ne 0 ]]; then
		print_error "此脚本必须以 root 权限运行"
		echo ""
		echo "请使用以下方式运行:"
		echo "  curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --hostname derp.example.com"
		exit 1
	fi
}

# Check hostname
check_hostname() {
	if [[ "$UNINSTALL_MODE" == "true" ]]; then
		return
	fi

	if [[ -z "$DERPER_HOSTNAME" ]]; then
		print_error "未指定域名"
		echo ""
		echo "请使用 --hostname 参数指定域名:"
		echo "  curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --hostname derp.example.com"
		exit 1
	fi
}

# Uninstall derper and tailscaled
uninstall_services() {
	print_step "开始卸载 Derper 和 Tailscaled..."
	echo ""

	# Confirm uninstallation
	if [[ "$KEEP_DATA" != "true" ]]; then
		print_warn "警告: 此操作将删除所有数据和配置文件！"
		read -p "确认卸载？ (yes/no): " confirm
		if [[ "$confirm" != "yes" ]]; then
			print_info "取消卸载"
			exit 0
		fi
	fi

	# Stop and disable derper service
	if systemctl is-active --quiet derper 2>/dev/null; then
		print_info "停止 derper 服务..."
		systemctl stop derper
	fi

	if systemctl is-enabled --quiet derper 2>/dev/null; then
		print_info "禁用 derper 服务..."
		systemctl disable derper
	fi

	# Stop and disable tailscaled service
	if systemctl is-active --quiet tailscaled 2>/dev/null; then
		print_info "停止 tailscaled 服务..."
		systemctl stop tailscaled
	fi

	if systemctl is-enabled --quiet tailscaled 2>/dev/null; then
		print_info "禁用 tailscaled 服务..."
		systemctl disable tailscaled
	fi

	# Remove service files
	if [[ -f /lib/systemd/system/derper.service ]]; then
		print_info "删除 derper systemd 服务文件..."
		rm -f /lib/systemd/system/derper.service
	fi

	if [[ -f /lib/systemd/system/tailscaled.service ]]; then
		print_info "删除 tailscaled systemd 服务文件..."
		rm -f /lib/systemd/system/tailscaled.service
	fi

	# Reload systemd
	systemctl daemon-reload

	# Remove binaries
	if [[ -f /usr/local/bin/derper ]]; then
		print_info "删除 derper 二进制文件..."
		rm -f /usr/local/bin/derper
	fi

	if [[ -f /usr/local/bin/tailscale ]]; then
		print_info "删除 tailscale 二进制文件..."
		rm -f /usr/local/bin/tailscale
	fi

	if [[ -f /usr/local/bin/tailscaled ]]; then
		print_info "删除 tailscaled 二进制文件..."
		rm -f /usr/local/bin/tailscaled
	fi

	# Remove or backup data
	if [[ "$KEEP_DATA" == "true" ]]; then
		print_info "保留配置文件和数据目录"
		echo "  配置文件: /etc/default/derper"
		echo "  数据目录: $DERPER_WORKDIR"
		echo "  数据目录: /var/lib/tailscale"
	else
		# Remove configuration files
		if [[ -f /etc/default/derper ]]; then
			print_info "删除 derper 配置文件..."
			rm -f /etc/default/derper
		fi

		if [[ -f /etc/default/tailscaled ]]; then
			print_info "删除 tailscaled 配置文件..."
			rm -f /etc/default/tailscaled
		fi

		# Remove data directories
		if [[ -d "$DERPER_WORKDIR" ]]; then
			print_info "删除 derper 数据目录..."
			rm -rf "$DERPER_WORKDIR"
		fi

		if [[ -d /var/lib/tailscale ]]; then
			print_info "删除 tailscale 数据目录..."
			rm -rf /var/lib/tailscale
		fi

		if [[ -d /var/log/derper ]]; then
			print_info "删除 derper 日志目录..."
			rm -rf /var/log/derper
		fi

		# Remove user
		if id -u derper >/dev/null 2>&1; then
			print_info "删除 derper 用户..."
			userdel derper 2>/dev/null || true
		fi
	fi

	echo ""
	print_info "===== 卸载完成 ====="
	echo ""

	if [[ "$KEEP_DATA" == "true" ]]; then
		echo "已保留以下文件和目录："
		echo "  - /etc/default/derper"
		echo "  - $DERPER_WORKDIR"
		echo "  - /var/lib/tailscale"
		echo ""
		echo "如需完全删除，请手动运行："
		echo "  sudo rm -rf /etc/default/derper $DERPER_WORKDIR /var/lib/tailscale /var/log/derper"
		echo "  sudo userdel derper"
	else
		echo "已完全卸载 Derper 和 Tailscaled"
	fi
	echo ""
}

# Detect architecture
detect_arch() {
	local arch=$(uname -m)
	case $arch in
	x86_64)
		echo "amd64"
		;;
	aarch64 | arm64)
		echo "arm64"
		;;
	armv7l | armv6l)
		echo "arm"
		;;
	*)
		print_error "不支持的架构: $arch"
		exit 1
		;;
	esac
}

# Check if running on Aliyun ECS
is_aliyun_ecs() {
	if timeout 2 curl -s http://100.100.100.200/latest/meta-data/instance-id >/dev/null 2>&1; then
		return 0
	fi
	return 1
}

# Get latest Go version
get_latest_go_version() {
	local version=$(curl -sL --max-time 10 https://golang.google.cn/VERSION?m=text 2>/dev/null | head -n1)

	if [[ -z "$version" ]]; then
		echo "1.23.4"
	else
		version="${version#go}"
		echo "$version"
	fi
}

# Download and setup temporary Go
setup_temp_go() {
	print_step "设置 Go 编译环境..."

	local go_version=$(get_latest_go_version)
	local arch=$(detect_arch)
	local go_tarball="go${go_version}.linux-${arch}.tar.gz"
	local temp_dir="/tmp/derper-install-$$"
	local download_success=false

	print_info "创建临时目录..."
	mkdir -p "$temp_dir"
	cd "$temp_dir"

	print_info "下载 Go ${go_version} for ${arch}..."

	local download_sources=()

	if [[ "$USE_ALIYUN_INTERNAL" == "true" ]]; then
		print_info "使用阿里云 ECS 内网镜像源..."
		download_sources=(
			"http://mirrors.cloud.aliyuncs.com/golang/${go_tarball}"
			"https://mirrors.aliyun.com/golang/${go_tarball}"
			"https://go.dev/dl/${go_tarball}"
		)
	elif is_aliyun_ecs; then
		print_info "检测到阿里云 ECS 环境，优先使用内网镜像源..."
		download_sources=(
			"http://mirrors.cloud.aliyuncs.com/golang/${go_tarball}"
			"https://mirrors.aliyun.com/golang/${go_tarball}"
			"https://go.dev/dl/${go_tarball}"
			"https://golang.google.cn/dl/${go_tarball}"
		)
	else
		download_sources=(
			"https://go.dev/dl/${go_tarball}"
			"https://mirrors.aliyun.com/golang/${go_tarball}"
			"https://golang.google.cn/dl/${go_tarball}"
		)
	fi

	for source in "${download_sources[@]}"; do
		print_info "尝试从 $source 下载..."
		if wget -q --show-progress --timeout=30 --tries=2 "$source"; then
			download_success=true
			print_info "下载成功！"
			break
		else
			print_warn "从 $source 下载失败"
		fi
	done

	if [[ "$download_success" == "false" ]]; then
		print_error "从所有镜像源下载 Go 失败"
		cleanup_temp "$temp_dir"
		exit 1
	fi

	print_info "解压 Go..."
	tar -xzf "$go_tarball"

	export GOROOT="$temp_dir/go"
	export PATH="$GOROOT/bin:$PATH"
	export GOPATH="$temp_dir/gopath"

	print_info "Go 版本: $(go version)"
	echo ""
}

# Set Go proxy
set_go_proxy() {
	if [[ "$USE_ALIYUN_INTERNAL" == "true" ]] || is_aliyun_ecs; then
		export GOPROXY="http://mirrors.cloud.aliyuncs.com/goproxy/,https://goproxy.io,https://proxy.golang.org,direct"
	else
		export GOPROXY="https://proxy.golang.org,https://goproxy.io,direct"
	fi
	export GOSUMDB="sum.golang.google.cn"
	print_info "Go 代理: $GOPROXY"
}

# Install derper
install_derper() {
	print_step "安装 Derper..."

	set_go_proxy

	local version_suffix="@latest"
	if [[ "$DERPER_VERSION" != "latest" ]]; then
		version_suffix="@v${DERPER_VERSION}"
		print_info "安装 derper 版本: ${DERPER_VERSION}"
	else
		print_info "安装最新版本的 derper"
	fi

	if ! go install "tailscale.com/cmd/derper${version_suffix}"; then
		print_error "安装 derper 失败"
		print_info "尝试使用备用代理..."
		export GOPROXY="https://goproxy.io,https://mirrors.aliyun.com/goproxy/,direct"
		if ! go install "tailscale.com/cmd/derper${version_suffix}"; then
			print_error "从所有源安装 derper 失败"
			exit 1
		fi
	fi

	print_info "复制 derper 二进制文件到 /usr/local/bin..."
	cp "$GOPATH/bin/derper" /usr/local/bin/derper
	chmod +x /usr/local/bin/derper

	print_info "Derper 版本: $(/usr/local/bin/derper -version)"
	echo ""
}

# Install tailscaled
install_tailscaled() {
	if [[ "$INSTALL_TAILSCALED" != "true" ]]; then
		return
	fi

	print_step "安装 Tailscaled..."

	set_go_proxy

	local version_suffix="@latest"
	if [[ "$TAILSCALE_VERSION" != "latest" ]]; then
		version_suffix="@v${TAILSCALE_VERSION}"
		print_info "安装 tailscale 版本: ${TAILSCALE_VERSION}"
	else
		print_info "安装最新版本的 tailscale"
	fi

	# Install tailscale and tailscaled
	if ! go install "tailscale.com/cmd/tailscale${version_suffix}"; then
		print_error "安装 tailscale 失败"
		print_info "尝试使用备用代理..."
		export GOPROXY="https://goproxy.io,https://mirrors.aliyun.com/goproxy/,direct"
		if ! go install "tailscale.com/cmd/tailscale${version_suffix}"; then
			print_error "从所有源安装 tailscale 失败"
			exit 1
		fi
	fi

	if ! go install "tailscale.com/cmd/tailscaled${version_suffix}"; then
		print_error "安装 tailscaled 失败"
		exit 1
	fi

	print_info "复制 tailscale 和 tailscaled 二进制文件..."
	cp "$GOPATH/bin/tailscale" /usr/local/bin/tailscale
	cp "$GOPATH/bin/tailscaled" /usr/local/bin/tailscaled
	chmod +x /usr/local/bin/tailscale
	chmod +x /usr/local/bin/tailscaled

	print_info "Tailscale 版本: $(/usr/local/bin/tailscale version)"
	echo ""

	# Create tailscaled systemd service
	create_tailscaled_service
}

# Create tailscaled systemd service
create_tailscaled_service() {
	print_info "创建 tailscaled systemd 服务..."

	mkdir -p /var/lib/tailscale

	cat >/lib/systemd/system/tailscaled.service <<'EOF'
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
Wants=network-pre.target
After=network-pre.target NetworkManager.service systemd-resolved.service

[Service]
EnvironmentFile=/etc/default/tailscaled
ExecStart=/usr/local/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=${PORT} $FLAGS
ExecStopPost=/usr/local/bin/tailscaled --cleanup

Restart=on-failure

RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
StateDirectory=tailscale
StateDirectoryMode=0700
CacheDirectory=tailscale
CacheDirectoryMode=0750
Type=notify

[Install]
WantedBy=multi-user.target
EOF

	chmod 644 /lib/systemd/system/tailscaled.service

	# Create tailscaled config
	cat >/etc/default/tailscaled <<'EOF'
# Tailscaled configuration
PORT=41641
FLAGS=""
EOF

	systemctl daemon-reload
	systemctl enable tailscaled
	systemctl start tailscaled

	if systemctl is-active --quiet tailscaled; then
		print_info "Tailscaled 服务启动成功！"
		print_info "使用 'tailscale up' 连接到 Tailscale 网络"
	else
		print_warn "Tailscaled 服务启动失败，请检查日志: journalctl -u tailscaled -f"
	fi
}

# Cleanup temporary files
cleanup_temp() {
	local temp_dir="$1"
	print_info "清理临时文件..."
	cd /
	rm -rf "$temp_dir"
}

# Create derper user
create_user() {
	print_step "配置系统用户和目录..."

	if ! id -u derper >/dev/null 2>&1; then
		print_info "创建 derper 用户..."
		useradd -r -s /bin/false -d "$DERPER_WORKDIR" derper
	else
		print_info "用户 'derper' 已存在"
	fi
}

# Create necessary directories
create_directories() {
	print_info "创建必要的目录..."
	mkdir -p "$DERPER_WORKDIR"
	mkdir -p "$DERPER_WORKDIR/certs"
	mkdir -p "$DERPER_WORKDIR/secrets"
	mkdir -p /var/log/derper

	chown -R derper:derper "$DERPER_WORKDIR"
	chown -R derper:derper /var/log/derper

	# Create certificate file and README for manual mode
	if [[ "$DERPER_CERTMODE" == "manual" ]]; then
		# check if openSSL is installed
		if ! command -v openssl >/dev/null 2>&1; then
			print_error "手动证书模式需要 OpenSSL，请先安装 OpenSSL"
			exit 1
		fi
		print_info "创建自签名证书和私钥作为占位符..."

		# Create placeholder cert and key files
		openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 --nodes \
			-keyout "$DERPER_WORKDIR/certs/${DERPER_HOSTNAME}.key" \
			-out "$DERPER_WORKDIR/certs/${DERPER_HOSTNAME}.crt" \
			-subj "/CN=${DERPER_HOSTNAME}" -addext "subjectAltName=DNS:${DERPER_HOSTNAME}"

		cat >"$DERPER_WORKDIR/certs/README.txt" <<EOF
手动证书模式使用说明
====================

请将您的证书文件放置在此目录下：

目录结构:
$DERPER_WORKDIR/certs
├── ${DERPER_HOSTNAME}.crt  (证书文件)
└── ${DERPER_HOSTNAME}.key  (私钥文件)

示例命令:

1. 生成证书
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 --nodes \
	-keyout ${DERPER_HOSTNAME}.key -out ${DERPER_HOSTNAME}.crt \
	-subj "/CN=${DERPER_HOSTNAME}" -addext "subjectAltName=DNS:${DERPER_HOSTNAME}"

2. 设置正确的权限:
   chown -R derper:derper $DERPER_WORKDIR/certs
   chmod 600 $DERPER_WORKDIR/certs/${DERPER_HOSTNAME}.key
   chmod 644 $DERPER_WORKDIR/certs/${DERPER_HOSTNAME}.crt

3. 重启 derper 服务:
   systemctl restart derper
EOF
		chown derper:derper "$DERPER_WORKDIR/certs/README.txt"
	fi

	echo ""
}

# Create configuration file
create_config() {
	print_step "生成配置文件..."

	cat >/etc/default/derper <<EOF
# Derper server configuration
# Generated on $(date)
# User: ${SUDO_USER:-root}

# Server listen address and port
DERPER_ADDR=":${DERPER_PORT}"

# HTTP port (set to -1 to disable)
DERPER_HTTP_PORT="${DERPER_HTTP_PORT}"

# STUN configuration
DERPER_STUN="${DERPER_STUN}"
DERPER_STUN_PORT="${DERPER_STUN_PORT}"

# Working directory
DERPER_WORKDIR="${DERPER_WORKDIR}"

# Hostname for LetsEncrypt
DERPER_HOSTNAME="${DERPER_HOSTNAME}"

# Certificate mode: letsencrypt or manual
DERPER_CERTMODE="${DERPER_CERTMODE}"

# Client verification
DERPER_VERIFY_CLIENTS="${DERPER_VERIFY_CLIENTS}"

# Additional arguments
DERPER_EXTRA_ARGS="${DERPER_EXTRA_ARGS}"

EOF

	chmod 644 /etc/default/derper
	print_info "配置文件已保存到: /etc/default/derper"
	echo ""
}

# Create systemd service
create_service() {
	print_step "创建 systemd 服务..."

	cat >/lib/systemd/system/derper.service <<'EOF'
[Unit]
Description=Tailscale DERP Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=derper
Group=derper
EnvironmentFile=/etc/default/derper

# Construct command line arguments
ExecStart=/bin/bash -c 'exec /usr/local/bin/derper \
    -a "${DERPER_ADDR}" \
    -http-port ${DERPER_HTTP_PORT} \
    -stun=${DERPER_STUN} \
    -stun-port ${DERPER_STUN_PORT} \
    ${DERPER_HOSTNAME:+-hostname "${DERPER_HOSTNAME}"} \
    -certmode "${DERPER_CERTMODE}" \
    -certdir "${DERPER_WORKDIR}/certs" \
    -secrets-cache-dir "${DERPER_WORKDIR}/secrets" \
    ${DERPER_VERIFY_CLIENTS:+-verify-clients="${DERPER_VERIFY_CLIENTS}"} \
    ${DERPER_EXTRA_ARGS} \
    -c ${DERPER_WORKDIR}/derper.key'

# Restart policy
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${DERPER_WORKDIR} /var/log/derper

# Capabilities
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

# Resource limits
LimitNOFILE=1048576

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=derper

[Install]
WantedBy=multi-user.target
EOF

	chmod 644 /lib/systemd/system/derper.service
	print_info "systemd 服务文件已创建"
	echo ""
}

# Enable and start service
enable_service() {
	print_step "启动 Derper 服务..."

	print_info "重新加载 systemd 守护进程..."
	systemctl daemon-reload

	print_info "启用 derper 服务..."
	systemctl enable derper

	print_info "启动 derper 服务..."
	systemctl start derper

	sleep 2

	if systemctl is-active --quiet derper; then
		print_info "Derper 服务启动成功！"
	else
		print_error "Derper 服务启动失败，请查看日志: journalctl -u derper -f"
		if [[ "$DERPER_CERTMODE" == "manual" ]]; then
			echo ""
			print_warn "如果您使用手动证书模式，请确保证书文件已正确放置："
			echo "  证书: $DERPER_WORKDIR/certs/${DERPER_HOSTNAME}.crt"
			echo "  私钥: $DERPER_WORKDIR/certs/${DERPER_HOSTNAME}.key"
			echo ""
			echo "查看证书配置说明:"
			echo "  cat $DERPER_WORKDIR/certs/README.txt"
		fi
		exit 1
	fi
	echo ""
}

# Show firewall rules
show_firewall_info() {
	print_step "防火墙配置说明"
	echo ""
	echo "请根据您的防火墙类型选择以下命令："
	echo ""
	print_line "$YELLOW" "UFW 防火墙:"
	echo "  sudo ufw allow ${DERPER_PORT}/tcp"
	if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
		echo "  sudo ufw allow ${DERPER_HTTP_PORT}/tcp"
	fi
	if [[ "$DERPER_STUN" == "true" ]]; then
		echo "  sudo ufw allow ${DERPER_STUN_PORT}/udp"
	fi
	if [[ "$INSTALL_TAILSCALED" == "true" ]]; then
		echo "  sudo ufw allow 41641/udp"
	fi
	echo ""
	print_line "$YELLOW" "firewalld 防火墙:"
	echo "  sudo firewall-cmd --permanent --add-port=${DERPER_PORT}/tcp"
	if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
		echo "  sudo firewall-cmd --permanent --add-port=${DERPER_HTTP_PORT}/tcp"
	fi
	if [[ "$DERPER_STUN" == "true" ]]; then
		echo "  sudo firewall-cmd --permanent --add-port=${DERPER_STUN_PORT}/udp"
	fi
	if [[ "$INSTALL_TAILSCALED" == "true" ]]; then
		echo "  sudo firewall-cmd --permanent --add-port=41641/udp"
	fi
	echo "  sudo firewall-cmd --reload"
	echo ""
	print_line "$YELLOW" "阿里云/腾讯云安全组:"
	echo "  需要在云控制台开放以下端口："
	echo "  - TCP ${DERPER_PORT}"
	if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
		echo "  - TCP ${DERPER_HTTP_PORT}"
	fi
	if [[ "$DERPER_STUN" == "true" ]]; then
		echo "  - UDP ${DERPER_STUN_PORT}"
	fi
	if [[ "$INSTALL_TAILSCALED" == "true" ]]; then
		echo "  - UDP 41641"
	fi
	echo ""
}

# Show final information
show_final_info() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	print_info "✅ 安装完成！"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	print_line "$GREEN" "📋 服务信息:"
	echo "  服务器域名: ${DERPER_HOSTNAME}"
	echo "  HTTPS 端口: ${DERPER_PORT}"
	if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
		echo "  HTTP 端口:  ${DERPER_HTTP_PORT}"
	fi
	if [[ "$DERPER_STUN" == "true" ]]; then
		echo "  STUN 端口:  ${DERPER_STUN_PORT} (UDP)"
	fi
	echo "  证书模式:   ${DERPER_CERTMODE}"
	echo ""

	print_line "$GREEN" "📁 文件位置:"
	echo "  配置文件: /etc/default/derper"
	echo "  工作目录: ${DERPER_WORKDIR}"
	echo "  证书目录: ${DERPER_WORKDIR}/certs"
	echo "  日志目录: /var/log/derper"
	echo ""

	if [[ "$DERPER_CERTMODE" == "manual" ]]; then
		print_line "$YELLOW" "⚠️  手动证书模式:"
		echo "  证书位置: ${DERPER_WORKDIR}/certs/${DERPER_HOSTNAME}.crt"
		echo "  私钥位置: ${DERPER_WORKDIR}/certs/${DERPER_HOSTNAME}.key"
		echo "  配置说明: cat ${DERPER_WORKDIR}/certs/README.txt"
		echo ""
	fi

	print_line "$GREEN" "🔧 常用命令:"
	echo "  查看状态: systemctl status derper"
	echo "  查看日志: journalctl -u derper -f"
	echo "  重启服务: systemctl restart derper"
	echo "  停止服务: systemctl stop derper"
	echo ""

	if [[ "$INSTALL_TAILSCALED" == "true" ]]; then
		print_line "$GREEN" "🌐 Tailscaled 信息:"
		echo "  查看状态: systemctl status tailscaled"
		echo "  连接网络: tailscale up"
		echo "  查看状态: tailscale status"
		echo "  查看 IP:  tailscale ip"
		echo ""
	fi

	show_firewall_info

	print_line "$GREEN" "📖 更多信息:"
	echo "  重新配置:"
	echo "    1. 编辑配置文件: sudo nano /etc/default/derper"
	echo "    2. 重启服务: sudo systemctl restart derper"
	echo ""
	echo "  卸载服务:"
	echo "    curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --uninstall"
	echo ""
	echo "  文档和支持:"
	echo "    GitHub: https://github.com/hydrz/derper-install-script"
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
}

# Main installation process
main() {
	# Show banner
	show_banner

	# Parse arguments
	parse_args "$@"

	# Check root
	check_root

	# Handle uninstall mode
	if [[ "$UNINSTALL_MODE" == "true" ]]; then
		uninstall_services
		exit 0
	fi

	# Check hostname
	check_hostname

	print_info "开始安装 Derper v${VERSION}..."
	if [[ "$INSTALL_TAILSCALED" == "true" ]]; then
		print_info "同时安装 Tailscaled..."
	fi
	echo ""

	local temp_dir="/tmp/derper-install-$$"

	# Setup and install
	setup_temp_go
	install_derper
	install_tailscaled

	# Cleanup Go installation
	cleanup_temp "$temp_dir"

	# Configure system
	create_user
	create_directories
	create_config
	create_service
	enable_service

	# Show completion info
	show_final_info
}

# Run main function
main "$@"
