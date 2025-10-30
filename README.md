# Derper 一键安装脚本

<div align="center">

![Derper](https://img.shields.io/badge/Derper-Installer-blue?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-2.1.0-orange?style=for-the-badge)

一键安装 Tailscale DERP 服务器的自动化脚本

[快速开始](#快速开始) • [功能特性](#功能特性) • [使用文档](#使用文档) • [常见问题](#常见问题)

</div>

---

## 📋 目录

- [功能特性](#功能特性)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [安装选项](#安装选项)
- [使用示例](#使用示例)
- [服务管理](#服务管理)
- [配置说明](#配置说明)
- [卸载指南](#卸载指南)
- [防火墙配置](#防火墙配置)
- [常见问题](#常见问题)
- [高级配置](#高级配置)
- [集成到 Tailscale](#集成到-tailscale)
- [性能优化](#性能优化)
- [故障排查](#故障排查)

## ✨ 功能特性

### 核心功能
- 🚀 **一键安装** - 通过 curl 管道直接安装，无需下载脚本
- 📦 **版本控制** - 支持安装指定版本或最新版本
- 🔧 **完整集成** - 自动配置 systemd 服务和开机自启
- 🔐 **证书管理** - 自动 LetsEncrypt 证书申请和续期
- 🎯 **STUN 支持** - 内置 STUN 服务器功能
- 🌐 **Tailscale 集成** - 可选安装 tailscaled 客户端

### 性能优化
- 🇨🇳 **国内加速** - 阿里云镜像加速支持
- 🔌 **ECS 优化** - 自动检测阿里云 ECS，使用内网镜像
- 🔄 **智能切换** - 多镜像源自动切换和重试
- ⚡ **零流量费** - ECS 内网下载无流量费用

### 安全特性
- 👤 **用户隔离** - 独立系统用户运行
- 🔒 **权限最小化** - 最小权限原则配置
- 🏠 **文件系统保护** - 严格的目录权限控制
- 📊 **资源限制** - 合理的系统资源限制

## 💻 系统要求

### 支持的操作系统
- ✅ Ubuntu 18.04+ / Debian 10+
- ✅ CentOS 7+ / RHEL 7+ / Rocky Linux 8+
- ✅ Fedora 30+
- ✅ 其他支持 systemd 的 Linux 发行版

### 支持的架构
- ✅ x86_64 (amd64)
- ✅ ARM64 (aarch64)
- ✅ ARMv7 / ARMv6

### 依赖软件
- `bash` 4.0+
- `wget` 或 `curl`
- `systemd`
- `tar`

## 🚀 快速开始

### 方式一：一键安装（推荐）

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | sudo bash -s - --hostname derp.example.com
```

### 方式二：下载后安装

```bash
# 下载脚本
wget https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh

# 或使用 curl
curl -O https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh

# 添加执行权限
chmod +x install.sh

# 运行安装
sudo ./install.sh --hostname derp.example.com
```

### 方式三：Git 克隆安装

```bash
# 克隆仓库
git clone https://github.com/hydrz/derper-install-script.git
cd derper-install-script

# 运行安装
sudo ./install.sh --hostname derp.example.com
```

## ⚙️ 安装选项

### 参数列表

```bash
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
```

## 📖 使用示例

### 基础安装

```bash
# 最简单的安装方式（自动 LetsEncrypt）
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --hostname derp.example.com
```

### 阿里云 ECS 安装

```bash
# 使用内网镜像加速，节省流量费用
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --hostname derp.example.com --aliyun-internal
```

### 安装指定版本

```bash
# 安装 1.90.4 版本
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --hostname derp.example.com -v 1.90.4
```

### 同时安装 Tailscaled

```bash
# 安装 Derper 和 Tailscaled
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --hostname derp.example.com --install-tailscaled
```

### 自定义端口

```bash
# 使用自定义端口
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - \
  --hostname derp.example.com \
  --port 8443 \
  --http-port 8080 \
  --stun-port 3479
```

### 手动证书模式

```bash
# 使用自己的证书
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - \
  --hostname derp.example.com \
  --certmode manual \
  --port 8443
```

### 禁用 STUN

```bash
# 只运行 DERP，不运行 STUN
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - \
  --hostname derp.example.com \
  --no-stun
```

### 完整配置示例

```bash
# 包含所有常用选项
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - \
  --hostname derp.example.com \
  --port 443 \
  --http-port 80 \
  --stun-port 3478 \
  --workdir /data/derper \
  --certmode letsencrypt \
  --install-tailscaled \
  -v 1.90.4 \
  --aliyun-internal
```

## 🔧 服务管理

### Derper 服务

```bash
# 查看服务状态
systemctl status derper

# 启动服务
systemctl start derper

# 停止服务
systemctl stop derper

# 重启服务
systemctl restart derper

# 查看实时日志
journalctl -u derper -f

# 查看最近 100 行日志
journalctl -u derper -n 100

# 查看今天的日志
journalctl -u derper --since today

# 禁用开机自启
systemctl disable derper

# 启用开机自启
systemctl enable derper
```

### Tailscaled 服务

```bash
# 查看服务状态
systemctl status tailscaled

# 连接到 Tailscale 网络
tailscale up

# 使用自定义登录服务器
tailscale up --login-server https://controlplane.example.com

# 查看连接状态
tailscale status

# 查看 IP 地址
tailscale ip

# 查看详细信息
tailscale status --json

# 断开连接
tailscale down

# 查看日志
journalctl -u tailscaled -f
```

## 📝 配置说明

### 配置文件位置

**Derper 配置**: `/etc/default/derper`

```bash
# 编辑配置文件
sudo nano /etc/default/derper

# 重启服务使配置生效
sudo systemctl restart derper
```

### 配置文件内容

```bash
# Server listen address and port
DERPER_ADDR=":443"

# HTTP port (set to -1 to disable)
DERPER_HTTP_PORT="80"

# STUN configuration
DERPER_STUN="true"
DERPER_STUN_PORT="3478"

# Working directory
DERPER_WORKDIR="/var/lib/derper"

# Hostname for LetsEncrypt
DERPER_HOSTNAME="derp.example.com"

# Certificate mode: letsencrypt or manual
DERPER_CERTMODE="letsencrypt"

# Client verification
DERPER_VERIFY_CLIENTS="false"

# Additional arguments
DERPER_EXTRA_ARGS=""
```

### 目录结构

```
/usr/local/bin/
├── derper              # Derper 二进制文件
├── tailscale           # Tailscale CLI（可选）
└── tailscaled          # Tailscaled 守护进程（可选）

/etc/default/
├── derper              # Derper 配置文件
└── tailscaled          # Tailscaled 配置文件（可选）

/lib/systemd/system/
├── derper.service      # Derper systemd 服务
└── tailscaled.service  # Tailscaled systemd 服务（可选）

/var/lib/derper/        # Derper 工作目录
├── derper.key          # Derper 配置密钥
├── certs/              # 证书目录
│   └── derp.example.com/
└── secrets/            # 密钥缓存目录

/var/lib/tailscale/     # Tailscale 数据目录（可选）
└── tailscaled.state    # Tailscale 状态文件

/var/log/derper/        # Derper 日志目录
```

## 🗑️ 卸载指南

### 完全卸载（删除所有数据）

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --uninstall
```

⚠️ **警告**: 此操作将删除所有配置和数据文件！

### 保留数据卸载

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --uninstall --keep-data
```

保留的文件：
- `/etc/default/derper` - 配置文件
- `/var/lib/derper` - 数据目录
- `/var/lib/tailscale` - Tailscale 数据

### 手动完全清理

```bash
# 停止并删除服务
sudo systemctl stop derper tailscaled
sudo systemctl disable derper tailscaled
sudo rm -f /lib/systemd/system/derper.service
sudo rm -f /lib/systemd/system/tailscaled.service
sudo systemctl daemon-reload

# 删除二进制文件
sudo rm -f /usr/local/bin/derper
sudo rm -f /usr/local/bin/tailscale
sudo rm -f /usr/local/bin/tailscaled

# 删除配置和数据
sudo rm -rf /etc/default/derper
sudo rm -rf /etc/default/tailscaled
sudo rm -rf /var/lib/derper
sudo rm -rf /var/lib/tailscale
sudo rm -rf /var/log/derper

# 删除用户
sudo userdel derper
```

## 🔥 防火墙配置

### UFW 防火墙

```bash
# 开放 Derper 端口
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 3478/udp   # STUN

# 如果安装了 Tailscaled
sudo ufw allow 41641/udp

# 启用防火墙
sudo ufw enable

# 查看规则
sudo ufw status numbered
```

### firewalld 防火墙

```bash
# 开放 Derper 端口
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=3478/udp

# 如果安装了 Tailscaled
sudo firewall-cmd --permanent --add-port=41641/udp

# 重载防火墙
sudo firewall-cmd --reload

# 查看已开放端口
sudo firewall-cmd --list-all
```

### 云服务器安全组

#### 阿里云

登录 [阿里云控制台](https://ecs.console.aliyun.com) > 安全组 > 配置规则 > 添加安全组规则

| 协议类型 | 端口范围 | 授权对象  | 描述             |
| -------- | -------- | --------- | ---------------- |
| TCP      | 443      | 0.0.0.0/0 | DERP HTTPS       |
| TCP      | 80       | 0.0.0.0/0 | DERP HTTP        |
| UDP      | 3478     | 0.0.0.0/0 | STUN             |
| UDP      | 41641    | 0.0.0.0/0 | Tailscale (可选) |

#### 腾讯云

登录 [腾讯云控制台](https://console.cloud.tencent.com/cvm/securitygroup) > 安全组 > 添加规则

配置同上。

## ❓ 常见问题

### 1. 服务启动失败

**问题**: `systemctl start derper` 失败

**解决方案**:

```bash
# 查看详细错误日志
journalctl -u derper -n 50 --no-pager

# 检查配置文件语法
cat /etc/default/derper

# 检查端口占用
sudo ss -tulnp | grep -E ':(443|80|3478)'

# 手动测试运行
sudo -u derper /usr/local/bin/derper -a :8443 -http-port -1
```

### 2. LetsEncrypt 证书申请失败

**问题**: 无法获取 SSL 证书

**解决方案**:

```bash
# 1. 检查域名 DNS 解析
dig derp.example.com +short
nslookup derp.example.com

# 2. 确保端口可访问
curl -I http://derp.example.com
curl -Ik https://derp.example.com

# 3. 检查防火墙
sudo ufw status
sudo firewall-cmd --list-all

# 4. 查看 derper 日志
journalctl -u derper -f

# 5. 使用手动证书模式
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --hostname derp.example.com --certmode manual
```

### 3. 下载速度慢

**问题**: 在国内下载 Go 或依赖很慢

**解决方案**:

```bash
# 使用阿里云内网镜像（仅阿里云 ECS）
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --hostname derp.example.com --aliyun-internal

# 脚本会自动检测阿里云 ECS 并使用内网镜像
```

### 4. 版本安装失败

**问题**: 指定版本安装失败

**解决方案**:

```bash
# 查看可用版本
curl -s https://api.github.com/repos/tailscale/tailscale/releases | grep tag_name

# 使用正确的版本号格式（不要加 v 前缀）
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --hostname derp.example.com -v 1.90.4
```

### 5. 端口被占用

**问题**: 默认端口 443 已被占用

**解决方案**:

```bash
# 查看端口占用
sudo ss -tulnp | grep :443

# 使用自定义端口
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - \
  --hostname derp.example.com \
  --port 8443 \
  --http-port 8080
```

### 6. 证书路径问题

**问题**: 手动证书模式下找不到证书

**解决方案**:

```bash
# 证书应放在工作目录的 certs 子目录下
# 默认路径: /var/lib/derper/certs/

# 目录结构应该是:
# /var/lib/derper/certs/derp.example.com/
# ├── derp.example.com.crt  # 证书文件
# └── derp.example.com.key  # 私钥文件

# 确保文件权限正确
sudo chown -R derper:derper /var/lib/derper/certs
sudo chmod 600 /var/lib/derper/certs/derp.example.com/*.key
sudo chmod 644 /var/lib/derper/certs/derp.example.com/*.crt
```

### 7. 重新安装

**问题**: 卸载后重新安装失败

**解决方案**:

```bash
# 1. 完全卸载
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --uninstall

# 2. 手动清理残留
sudo rm -rf /var/lib/derper /var/lib/tailscale /var/log/derper
sudo userdel derper 2>/dev/null || true

# 3. 重新安装
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - --hostname derp.example.com
```

## 🔬 高级配置

### 1. DERP 网格配置

配置多个 DERP 服务器互联：

```bash
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - \
  --hostname derp1.example.com \
  --extra-args "-mesh-with derp2.example.com,derp3.example.com"
```

### 2. 自定义工作目录

使用自定义数据目录（如独立磁盘）：

```bash
# 创建并挂载数据目录
sudo mkdir -p /data/derper

# 安装到自定义目录
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - \
  --hostname derp.example.com \
  --workdir /data/derper
```

### 3. 使用自签名证书

```bash
# 1. 生成自签名证书
mkdir -p /var/lib/derper/certs
export DERPER_HOSTNAME=derp.example.com

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout /var/lib/derper/certs/${DERPER_HOSTNAME}.key -out /var/lib/derper/certs/${DERPER_HOSTNAME}.crt \
	-subj "/CN=${DERPER_HOSTNAME}" -addext "subjectAltName=DNS:${DERPER_HOSTNAME}"

# 2. 设置权限
sudo chown -R derper:derper /var/lib/derper/certs
sudo chmod 600 /var/lib/derper/certs/*.key
sudo chmod 644 /var/lib/derper/certs/*.cert

# 3. 安装（手动证书模式）
curl -fsSL https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh | \
  sudo bash -s - \
  --hostname derp.example.com \
  --certmode manual
```

### 4. 性能调优

编辑 systemd 服务文件以优化性能：

```bash
sudo nano /lib/systemd/system/derper.service
```

添加资源限制：

```ini
[Service]
# 增加文件描述符限制
LimitNOFILE=1048576

# CPU 限制（200% = 2 核心）
CPUQuota=200%

# 内存限制
MemoryLimit=2G

# 网络优化
Environment="GOGC=50"
Environment="GOMAXPROCS=4"
```

重载并重启：

```bash
sudo systemctl daemon-reload
sudo systemctl restart derper
```

### 5. 日志轮转配置

创建日志轮转规则：

```bash
sudo tee /etc/logrotate.d/derper << 'EOF'
/var/log/derper/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 derper derper
    sharedscripts
    postrotate
        systemctl reload derper > /dev/null 2>&1 || true
    endscript
}
EOF
```

手动触发轮转：

```bash
sudo logrotate -f /etc/logrotate.d/derper
```

### 6. 监控和告警

使用 systemd 监控服务状态：

```bash
# 实时监控服务状态
watch -n 1 'systemctl status derper | head -20'

# 配置失败时发送邮件
sudo systemctl edit derper
```

添加以下内容：

```ini
[Unit]
OnFailure=status-email@%n.service
```

## 🌐 集成到 Tailscale

### 添加自定义 DERP 服务器

在 Tailscale 管理后台（Access Controls）添加：

详细参数可以查看[https://pkg.go.dev/tailscale.com/tailcfg#DERPNode](https://pkg.go.dev/tailscale.com/tailcfg#DERPNode)

```json
{
  "derpMap": {
    "OmitDefaultRegions": false,
    "Regions": {
      "900": {
        "RegionID": 900,
        "RegionCode": "custom",
        "RegionName": "Custom DERP",
      	"Latitude":   30.29365,
				"Longitude":  120.16142,
        "Nodes": [
          {
            "Name": "900a",
            "RegionID": 900,
            "HostName": "derp.example.com",
            "DERPPort": 443,
            "STUNPort": 3478,
            "CanPort80": true,
          }
        ]
      }
    }
  }
}
```

### 使用自托管 DERP

```json
{
  "derpMap": {
    "OmitDefaultRegions": true,
    "Regions": {
      "901": {
        "RegionID": 901,
        "RegionCode": "cn-sh",
        "RegionName": "Shanghai",
        "Nodes": [
          {
            "Name": "901a",
            "RegionID": 901,
            "HostName": "derp-sh.example.com",
            "DERPPort": 443,
            "STUNPort": 3478
          }
        ]
      },
      "902": {
        "RegionID": 902,
        "RegionCode": "cn-bj",
        "RegionName": "Beijing",
        "Nodes": [
          {
            "Name": "902a",
            "RegionID": 902,
            "HostName": "derp-bj.example.com",
            "DERPPort": 443,
            "STUNPort": 3478
          }
        ]
      }
    }
  }
}
```

### 验证 DERP 服务器

```bash
# 使用 curl 测试
curl -v https://derp.example.com/derp

# 应该返回 "DERP requires connection upgrade"

# 测试 STUN
nc -u derp.example.com 3478

# 查看 Tailscale 日志
tailscale debug derp derp.example.com
```

## ⚡ 性能优化

### 系统内核参数优化

```bash
# 编辑 sysctl 配置
sudo nano /etc/sysctl.d/99-derper.conf
```

添加以下内容：

```ini
# Network performance tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr

# Connection tracking
net.netfilter.nf_conntrack_max = 1048576
net.nf_conntrack_max = 1048576

# File descriptors
fs.file-max = 2097152
```

应用配置：

```bash
sudo sysctl -p /etc/sysctl.d/99-derper.conf
```

### 进程资源限制

```bash
# 编辑 limits 配置
sudo nano /etc/security/limits.d/derper.conf
```

添加：

```ini
derper soft nofile 1048576
derper hard nofile 1048576
derper soft nproc 65535
derper hard nproc 65535
```

### 监控指标

```bash
# 查看连接数
ss -s

# 查看 derper 进程资源占用
top -p $(pgrep derper)

# 查看网络统计
netstat -s

# 查看文件描述符使用
lsof -p $(pgrep derper) | wc -l
```

## 🔍 故障排查

### 查看详细日志

```bash
# 查看所有 derper 日志
journalctl -u derper --no-pager

# 查看错误日志
journalctl -u derper -p err --no-pager

# 导出日志到文件
journalctl -u derper > derper.log
```

### 网络诊断

```bash
# 测试 HTTPS 连接
openssl s_client -connect derp.example.com:443

# 测试 HTTP 连接
curl -I http://derp.example.com

# 检查 DNS 解析
nslookup derp.example.com
dig derp.example.com

# 测试端口连通性
telnet derp.example.com 443
nc -vz derp.example.com 443
```

### 性能测试

```bash
# HTTP 压力测试
ab -n 1000 -c 10 https://derp.example.com/

# 网络带宽测试
iperf3 -c derp.example.com -p 5201
```

### 调试模式

```bash
# 停止服务
sudo systemctl stop derper

# 手动运行并查看输出
sudo -u derper /usr/local/bin/derper \
  -a :443 \
  -hostname derp.example.com \
  -certmode letsencrypt \
  -certdir /var/lib/derper/certs \
  -c /var/lib/derper/derper.key \
  -verbose
```

## 📚 更多资源

### 官方文档
- [Tailscale 官方文档](https://tailscale.com/kb/)
- [自定义 DERP 服务器](https://tailscale.com/kb/1118/custom-derp-servers)
- [Tailscale GitHub](https://github.com/tailscale/tailscale)

<div align="center">

Made with ❤️ by [hydrz](https://github.com/hydrz)

[⬆ 回到顶部](#derper-一键安装脚本)

</div>