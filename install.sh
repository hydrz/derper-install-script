#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DERPER_PORT="443"
DERPER_HTTP_PORT="80"
DERPER_STUN_PORT="3478"
DERPER_HOSTNAME=""
DERPER_CERTMODE="letsencrypt"
DERPER_CERTDIR="/var/lib/derper/certs"
DERPER_STUN="true"
DERPER_VERIFY_CLIENTS="false"
DERPER_EXTRA_ARGS=""
USE_ALIYUN_INTERNAL="false"

# Print colored message
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install Derper server and configure it as a systemd service.

OPTIONS:
    -h, --help                  Show this help message
    --port PORT                 HTTPS listen port (default: 443)
    --http-port PORT            HTTP port (default: 80)
    --stun-port PORT            STUN UDP port (default: 3478)
    --hostname HOSTNAME         Server hostname for LetsEncrypt
    --certmode MODE             Certificate mode: letsencrypt or manual (default: letsencrypt)
    --certdir DIR               Directory for certificates (default: /var/lib/derper/certs)
    --no-stun                   Disable STUN server
    --verify-clients            Enable client verification through local tailscaled
    --extra-args "ARGS"         Additional arguments to pass to derper
    --aliyun-internal           Use Aliyun ECS internal mirror (mirrors.cloud.aliyuncs.com)

EXAMPLES:
    # Basic installation with LetsEncrypt
    $0 --hostname derp.example.com

    # Installation on Aliyun ECS (use internal mirror)
    $0 --hostname derp.example.com --aliyun-internal

    # Manual certificate mode
    $0 --hostname derp.example.com --certmode manual --port 8443

    # Disable STUN and use custom ports
    $0 --hostname derp.example.com --no-stun --port 8443 --http-port 8080

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
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
            --certmode)
                DERPER_CERTMODE="$2"
                shift 2
                ;;
            --certdir)
                DERPER_CERTDIR="$2"
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
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Detect architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armv6l)
            echo "arm"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Check if running on Aliyun ECS
is_aliyun_ecs() {
    # Check if we can access Aliyun metadata service
    if timeout 2 curl -s http://100.100.100.200/latest/meta-data/instance-id >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Get latest Go version from official website
get_latest_go_version() {
    # Try to get the latest stable version from Go download page
    local version=$(curl -sL --max-time 10 https://golang.google.cn/VERSION?m=text 2>/dev/null | head -n1)

    if [[ -z "$version" ]]; then
        echo "1.25.3"
    else
        # Remove "go" prefix if present
        version="${version#go}"
        echo "$version"
    fi
}

# Download and setup temporary Go
setup_temp_go() {
    local go_version=$(get_latest_go_version)
    local arch=$(detect_arch)
    local go_tarball="go${go_version}.linux-${arch}.tar.gz"
    local temp_dir="/tmp/derper-install-$$"
    local download_success=false

    print_info "创建临时目录..."
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    print_info "下载 Go ${go_version} for ${arch}..."

    # Determine download sources based on environment
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

    # Try each download source
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
}

# Install derper
install_derper() {
    print_info "从源码安装 derper..."

    # Set Go proxy based on environment
    if [[ "$USE_ALIYUN_INTERNAL" == "true" ]] || is_aliyun_ecs; then
        print_info "使用阿里云 Go 代理..."
        export GOPROXY="https://mirrors.aliyun.com/goproxy/,https://goproxy.cn,direct"
    else
        export GOPROXY="https://goproxy.cn,https://proxy.golang.org,direct"
    fi
    export GOSUMDB="sum.golang.google.cn"

    print_info "Go 代理: $GOPROXY"

    if ! go install tailscale.com/cmd/derper@latest; then
        print_error "安装 derper 失败"
        print_info "尝试使用备用代理..."
        export GOPROXY="https://goproxy.io,https://mirrors.aliyun.com/goproxy/,direct"
        if ! go install tailscale.com/cmd/derper@latest; then
            print_error "从所有源安装 derper 失败"
            exit 1
        fi
    fi

    print_info "复制 derper 二进制文件到 /usr/local/bin..."
    cp "$GOPATH/bin/derper" /usr/local/bin/derper
    chmod +x /usr/local/bin/derper

    print_info "Derper 版本: $(/usr/local/bin/derper -version)"
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
    if ! id -u derper >/dev/null 2>&1; then
        print_info "创建 derper 用户..."
        useradd -r -s /bin/false -d /var/lib/derper derper
    else
        print_info "用户 'derper' 已存在"
    fi
}

# Create necessary directories
create_directories() {
    print_info "创建必要的目录..."
    mkdir -p "$DERPER_CERTDIR"
    mkdir -p /var/lib/derper
    mkdir -p /var/log/derper

    chown -R derper:derper /var/lib/derper
    chown -R derper:derper /var/log/derper
    chown -R derper:derper "$DERPER_CERTDIR"
}

# Create configuration file
create_config() {
    print_info "创建配置文件 /etc/default/derper..."

    cat > /etc/default/derper << EOF
# Derper server configuration
# Generated on $(date)

# Server listen address and port
DERPER_ADDR=":${DERPER_PORT}"

# HTTP port (set to -1 to disable)
DERPER_HTTP_PORT="${DERPER_HTTP_PORT}"

# STUN configuration
DERPER_STUN="${DERPER_STUN}"
DERPER_STUN_PORT="${DERPER_STUN_PORT}"

# Hostname for LetsEncrypt
DERPER_HOSTNAME="${DERPER_HOSTNAME}"

# Certificate mode: letsencrypt or manual
DERPER_CERTMODE="${DERPER_CERTMODE}"

# Certificate directory
DERPER_CERTDIR="${DERPER_CERTDIR}"

# Client verification
DERPER_VERIFY_CLIENTS="${DERPER_VERIFY_CLIENTS}"

# Additional arguments
DERPER_EXTRA_ARGS="${DERPER_EXTRA_ARGS}"

EOF

    chmod 644 /etc/default/derper
}

# Create systemd service
create_service() {
    print_info "创建 systemd 服务..."

    cat > /etc/systemd/system/derper.service << 'EOF'
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
    -certdir "${DERPER_CERTDIR}" \
    ${DERPER_VERIFY_CLIENTS:+-verify-clients="${DERPER_VERIFY_CLIENTS}"} \
    ${DERPER_EXTRA_ARGS}'

# Restart policy
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/derper /var/log/derper

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

    chmod 644 /etc/systemd/system/derper.service
}

# Enable and start service
enable_service() {
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
        exit 1
    fi
}

# Show firewall rules
show_firewall_info() {
    print_info "防火墙配置说明："
    echo ""
    echo "  UFW 防火墙："
    echo "    sudo ufw allow ${DERPER_PORT}/tcp"
    if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
        echo "    sudo ufw allow ${DERPER_HTTP_PORT}/tcp"
    fi
    if [[ "$DERPER_STUN" == "true" ]]; then
        echo "    sudo ufw allow ${DERPER_STUN_PORT}/udp"
    fi
    echo ""
    echo "  firewalld 防火墙："
    echo "    sudo firewall-cmd --permanent --add-port=${DERPER_PORT}/tcp"
    if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
        echo "    sudo firewall-cmd --permanent --add-port=${DERPER_HTTP_PORT}/tcp"
    fi
    if [[ "$DERPER_STUN" == "true" ]]; then
        echo "    sudo firewall-cmd --permanent --add-port=${DERPER_STUN_PORT}/udp"
    fi
    echo "    sudo firewall-cmd --reload"
    echo ""
    echo "  阿里云安全组："
    echo "    需要在控制台开放 TCP ${DERPER_PORT}"
    if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
        echo "    需要在控制台开放 TCP ${DERPER_HTTP_PORT}"
    fi
    if [[ "$DERPER_STUN" == "true" ]]; then
        echo "    需要在控制台开放 UDP ${DERPER_STUN_PORT}"
    fi
    echo ""
}

# Show final information
show_final_info() {
    echo ""
    print_info "===== 安装完成 ====="
    echo ""
    echo "Derper 已成功安装并启动！"
    echo ""
    echo "配置文件: /etc/default/derper"
    echo "服务状态: systemctl status derper"
    echo "查看日志: journalctl -u derper -f"
    echo ""

    if [[ -n "$DERPER_HOSTNAME" ]]; then
        echo "服务器域名: $DERPER_HOSTNAME"
    fi
    echo "HTTPS 端口: $DERPER_PORT"
    if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
        echo "HTTP 端口: $DERPER_HTTP_PORT"
    fi
    if [[ "$DERPER_STUN" == "true" ]]; then
        echo "STUN 端口: $DERPER_STUN_PORT (UDP)"
    fi
    echo ""

    show_firewall_info

    echo ""
    echo "重新配置 derper:"
    echo "  1. 编辑 /etc/default/derper"
    echo "  2. 运行: systemctl restart derper"
    echo ""
}

# Main installation process
main() {
    parse_args "$@"

    print_info "开始安装 Derper..."
    echo ""

    check_root

    local temp_dir="/tmp/derper-install-$$"

    # Setup and install
    setup_temp_go
    install_derper

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