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

EXAMPLES:
    # Basic installation with LetsEncrypt
    $0 --hostname derp.example.com

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

# Get latest Go version from official website
get_latest_go_version() {
    print_info "Fetching latest Go version..."

    # Try to get the latest stable version from Go download page
    local version=$(curl -sL https://go.dev/VERSION?m=text | head -n1)

    if [[ -z "$version" ]]; then
        print_warn "Failed to fetch latest Go version, using fallback version 1.25.3"
        echo "1.25.3"
    else
        # Remove "go" prefix if present
        version="${version#go}"
        print_info "Latest Go version: $version"
        echo "$version"
    fi
}

# Download and setup temporary Go
setup_temp_go() {
    local go_version=$(get_latest_go_version)
    local arch=$(detect_arch)
    local go_tarball="go${go_version}.linux-${arch}.tar.gz"
    local temp_dir="/tmp/derper-install-$$"

    print_info "Creating temporary directory..."
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    print_info "Downloading Go ${go_version} for ${arch}..."
    if ! wget -q --show-progress "https://go.dev/dl/${go_tarball}"; then
        print_error "Failed to download Go ${go_version}"
        print_info "Trying to download from Google CDN..."
        if ! wget -q --show-progress "https://golang.google.cn/dl/${go_tarball}"; then
            print_error "Failed to download Go from all sources"
            cleanup_temp "$temp_dir"
            exit 1
        fi
    fi

    print_info "Extracting Go..."
    tar -xzf "$go_tarball"

    export GOROOT="$temp_dir/go"
    export PATH="$GOROOT/bin:$PATH"
    export GOPATH="$temp_dir/gopath"

    print_info "Go version: $(go version)"
}

# Install derper
install_derper() {
    print_info "Installing derper from source..."

    # Set Go environment for faster downloads in China
    export GOPROXY="https://proxy.golang.org,direct"
    export GOSUMDB="sum.golang.org"

    if ! go install tailscale.com/cmd/derper@latest; then
        print_error "Failed to install derper"
        print_info "Trying with China proxy..."
        export GOPROXY="https://goproxy.cn,direct"
        if ! go install tailscale.com/cmd/derper@latest; then
            print_error "Failed to install derper from all sources"
            exit 1
        fi
    fi

    print_info "Copying derper binary to /usr/local/bin..."
    cp "$GOPATH/bin/derper" /usr/local/bin/derper
    chmod +x /usr/local/bin/derper

    print_info "Derper version: $(/usr/local/bin/derper -version)"
}

# Cleanup temporary files
cleanup_temp() {
    local temp_dir="$1"
    print_info "Cleaning up temporary files..."
    cd /
    rm -rf "$temp_dir"
}

# Create derper user
create_user() {
    if ! id -u derper >/dev/null 2>&1; then
        print_info "Creating derper user..."
        useradd -r -s /bin/false -d /var/lib/derper derper
    else
        print_info "User 'derper' already exists"
    fi
}

# Create necessary directories
create_directories() {
    print_info "Creating directories..."
    mkdir -p "$DERPER_CERTDIR"
    mkdir -p /var/lib/derper
    mkdir -p /var/log/derper

    chown -R derper:derper /var/lib/derper
    chown -R derper:derper /var/log/derper
    chown -R derper:derper "$DERPER_CERTDIR"
}

# Create configuration file
create_config() {
    print_info "Creating configuration file at /etc/default/derper..."

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
    print_info "Creating systemd service..."

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
    print_info "Reloading systemd daemon..."
    systemctl daemon-reload

    print_info "Enabling derper service..."
    systemctl enable derper

    print_info "Starting derper service..."
    systemctl start derper

    sleep 2

    if systemctl is-active --quiet derper; then
        print_info "Derper service started successfully!"
    else
        print_error "Derper service failed to start. Check logs with: journalctl -u derper -f"
        exit 1
    fi
}

# Show firewall rules
show_firewall_info() {
    print_info "Firewall configuration needed:"
    echo ""
    echo "  For UFW:"
    echo "    sudo ufw allow ${DERPER_PORT}/tcp"
    if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
        echo "    sudo ufw allow ${DERPER_HTTP_PORT}/tcp"
    fi
    if [[ "$DERPER_STUN" == "true" ]]; then
        echo "    sudo ufw allow ${DERPER_STUN_PORT}/udp"
    fi
    echo ""
    echo "  For firewalld:"
    echo "    sudo firewall-cmd --permanent --add-port=${DERPER_PORT}/tcp"
    if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
        echo "    sudo firewall-cmd --permanent --add-port=${DERPER_HTTP_PORT}/tcp"
    fi
    if [[ "$DERPER_STUN" == "true" ]]; then
        echo "    sudo firewall-cmd --permanent --add-port=${DERPER_STUN_PORT}/udp"
    fi
    echo "    sudo firewall-cmd --reload"
    echo ""
}

# Show final information
show_final_info() {
    echo ""
    print_info "===== Installation Complete ====="
    echo ""
    echo "Derper has been installed and started successfully!"
    echo ""
    echo "Configuration file: /etc/default/derper"
    echo "Service status: systemctl status derper"
    echo "View logs: journalctl -u derper -f"
    echo ""

    if [[ -n "$DERPER_HOSTNAME" ]]; then
        echo "Server hostname: $DERPER_HOSTNAME"
    fi
    echo "HTTPS port: $DERPER_PORT"
    if [[ "$DERPER_HTTP_PORT" != "-1" ]]; then
        echo "HTTP port: $DERPER_HTTP_PORT"
    fi
    if [[ "$DERPER_STUN" == "true" ]]; then
        echo "STUN port: $DERPER_STUN_PORT (UDP)"
    fi
    echo ""

    show_firewall_info

    echo ""
    echo "To reconfigure derper:"
    echo "  1. Edit /etc/default/derper"
    echo "  2. Run: systemctl restart derper"
    echo ""
}

# Main installation process
main() {
    parse_args "$@"

    print_info "Starting Derper installation..."
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