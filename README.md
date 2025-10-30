
# derper-install-script

## 功能特性

✅ **自动下载和安装临时 Go 环境**

✅ **从源码编译最新版本的 derper**

✅ **安装后自动清理临时文件**

✅ **创建专用系统用户**

✅ **支持通过命令行参数配置**

✅ **配置保存在 `/etc/default/derper`**

✅ **systemd 服务管理**

✅ **安全加固（最小权限、隔离等）**

✅ **自动重启策略**

✅ **支持 LetsEncrypt 和手动证书模式**


## 使用说明

### 基本安装

使用 LetsEncrypt 自动证书：
```bash
curl https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh  | sudo bash -s - --hostname derp.example.com
```


### 高级配置示例

1. **使用手动证书模式**：
```bash
curl https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh  | sudo bash -s -  \
  --hostname derp.example.com \
  --certmode manual \
  --port 8443
```


2. **禁用 STUN，使用自定义端口**：
```bash
curl https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh  | sudo bash -s -  \
  --hostname derp.example.com \
  --no-stun \
  --port 8443 \
  --http-port 8080
```


3. **启用客户端验证**：
```bash
curl https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh  | sudo bash -s -  \
  --hostname derp.example.com \
  --verify-clients
```


4. **传递额外参数**：
```bash
curl https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh  | sudo bash -s -  \
  --hostname derp.example.com \
  --extra-args "-mesh-with derp1.example.com,derp2.example.com"
```

5. **安装指定版本**：
```bash
curl https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh  | sudo bash -s - \
  --hostname derp.example.com \
  -v 1.90.4
```

6. **同时安装 tailscaled**：
```bash
curl https://fastly.jsdelivr.net/gh/hydrz/derper-install-script/install.sh  | sudo bash -s - \
  --hostname derp.example.com \
  --install-tailscaled
```


### 管理服务

```bash
# 查看服务状态
systemctl status derper

# 查看日志
journalctl -u derper -f

# 重启服务
systemctl restart derper

# 停止服务
systemctl stop derper

# 禁用服务
systemctl disable derper
```

### 修改配置

1. 编辑配置文件：
```bash
sudo nano /etc/default/derper
```

2. 重启服务使配置生效：
```bash
sudo systemctl restart derper
```

### 配置文件示例 (`/etc/default/derper`)

```bash
# Derper server configuration

# Server listen address and port
DERPER_ADDR=":443"

# HTTP port (set to -1 to disable)
DERPER_HTTP_PORT="80"

# STUN configuration
DERPER_STUN="true"
DERPER_STUN_PORT="3478"

# Hostname for LetsEncrypt
DERPER_HOSTNAME="derp.example.com"

# Certificate mode: letsencrypt or manual
DERPER_CERTMODE="letsencrypt"

# Certificate directory
DERPER_CERTDIR="/var/lib/derper/certs"

# Client verification
DERPER_VERIFY_CLIENTS="false"

# Additional arguments
DERPER_EXTRA_ARGS=""
```