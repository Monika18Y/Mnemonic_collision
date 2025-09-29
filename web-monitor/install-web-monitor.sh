#!/bin/bash

# TRON 私钥碰撞工具 - Web监控界面安装脚本
# 适用于 Rocky Linux 9.0

set -e

echo "🚀 开始安装 TRON 碰撞工具 Web 监控界面..."

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "❌ 请不要使用root用户运行此脚本"
   exit 1
fi

# 检查必要文件
REQUIRED_FILES=("web_monitor.py" "templates/index.html" "web-requirements.txt")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ 找不到必要文件: $file"
        echo "请确保在正确的目录下运行此脚本"
        exit 1
    fi
done

# 检查基础服务是否已安装
if ! systemctl list-unit-files | grep -q "tron-collision.service"; then
    echo "⚠️  警告：未检测到基础TRON碰撞服务"
    read -p "是否继续安装Web监控？基础服务可以稍后安装 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "请先运行 install-rocky.sh 安装基础服务"
        exit 1
    fi
fi

# 检查是否需要安装Python基础环境
echo "🔍 检查系统依赖..."
MISSING_PACKAGES=()

# 检查Python3
if ! command -v python3 &> /dev/null; then
    MISSING_PACKAGES+=("python3")
fi

# 检查pip
if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
    MISSING_PACKAGES+=("python3-pip")
fi

# 安装缺失的包
if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "📦 需要安装缺失的系统包: ${MISSING_PACKAGES[*]}"
    echo "🤔 这些包可能在主服务安装时已安装，继续安装Web监控依赖"
    sudo dnf install -y "${MISSING_PACKAGES[@]}"
else
    echo "✅ 系统依赖检查完成，所有必要包已安装"
fi

# 创建Web监控目录
echo "📁 创建Web监控目录..."
sudo mkdir -p /opt/tron-web-monitor
sudo cp -r web_monitor.py templates static web-requirements.txt /opt/tron-web-monitor/

# 安装Web依赖
echo "📚 安装Web监控依赖..."
cd /opt/tron-web-monitor

# 检查虚拟环境是否存在
if [ ! -d "venv" ]; then
    echo "🐍 创建Python虚拟环境..."
    sudo python3 -m venv venv
fi

# 智能清华源配置
echo "🌐 选择Web监控Python包源："
echo "  1) 自动检测（推荐）- 检测主服务配置"
echo "  2) 使用默认源"
echo "  3) 强制使用清华源"
read -p "请选择 [1/2/3，默认1]: " -n 1 -r
echo
WEB_PIP_SOURCE=${REPLY:-1}

if [[ $WEB_PIP_SOURCE == "1" ]]; then
    # 自动检测模式
    if [ -f "/home/tron/.pip/pip.conf" ]; then
        echo "🇨🇳 检测到主服务已配置清华源，继承配置"
        PIP_INDEX="-i https://pypi.tuna.tsinghua.edu.cn/simple"
        USE_TSINGHUA_PIP=true
    else
        echo "🌐 主服务未配置清华源，使用默认源"
        PIP_INDEX=""
        USE_TSINGHUA_PIP=false
    fi
elif [[ $WEB_PIP_SOURCE == "3" ]]; then
    # 强制清华源模式
    echo "🚀 强制配置清华源"
    PIP_INDEX="-i https://pypi.tuna.tsinghua.edu.cn/simple"
    USE_TSINGHUA_PIP=true
else
    # 默认源模式
    echo "🌐 使用默认源"
    PIP_INDEX=""
    USE_TSINGHUA_PIP=false
fi

# 如果使用清华源，为Web监控用户配置pip源
if [ "$USE_TSINGHUA_PIP" = true ]; then
    echo "🐍 配置Web监控用户的pip清华源..."
    sudo mkdir -p /home/tronweb/.pip
    sudo tee /home/tronweb/.pip/pip.conf > /dev/null <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 120
EOF
fi

sudo ./venv/bin/pip install --upgrade pip $PIP_INDEX
sudo ./venv/bin/pip install -r web-requirements.txt $PIP_INDEX

# 创建Web监控用户（如果不存在）
echo "👤 创建Web监控用户..."
if ! id "tronweb" &>/dev/null; then
    sudo useradd -r -s /bin/false -d /opt/tron-web-monitor tronweb
    echo "✅ 用户 'tronweb' 创建成功"
else
    echo "ℹ️  用户 'tronweb' 已存在"
fi

# 设置权限
echo "🔒 设置目录权限..."
sudo chown -R tronweb:tronweb /opt/tron-web-monitor

# 设置pip配置文件权限（如果使用了清华源）
if [ "$USE_TSINGHUA_PIP" = true ]; then
    sudo chown -R tronweb:tronweb /home/tronweb/.pip 2>/dev/null || true
fi

# 添加用户到tron组（用于读取日志）
sudo usermod -a -G tron tronweb

# 创建Web监控systemd服务
echo "⚙️ 创建Web监控系统服务..."
sudo tee /etc/systemd/system/tron-web-monitor.service > /dev/null <<EOF
[Unit]
Description=TRON Collision Web Monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=tronweb
Group=tronweb
WorkingDirectory=/opt/tron-web-monitor
Environment=PATH=/opt/tron-web-monitor/venv/bin
Environment=FLASK_ENV=production
ExecStart=/opt/tron-web-monitor/venv/bin/python web_monitor.py
Restart=always
RestartSec=10
StartLimitInterval=350
StartLimitBurst=10

# 日志配置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tron-web-monitor

# 安全配置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/tron-web-monitor
ReadOnlyPaths=/opt/tron-collision

[Install]
WantedBy=multi-user.target
EOF

# 配置防火墙开放Web端口
echo "🔥 配置防火墙开放5168端口..."
if systemctl is-active --quiet firewalld; then
    echo "ℹ️  配置firewalld防火墙规则..."
    sudo firewall-cmd --permanent --add-port=5168/tcp
    sudo firewall-cmd --reload
    echo "✅ 已开放5168端口"
else
    echo "⚠️  firewalld未运行，请手动配置防火墙开放5168端口"
fi

# 配置sudo权限（让tronweb用户可以控制tron-collision服务）
echo "🔐 配置服务控制权限..."
sudo tee /etc/sudoers.d/tronweb > /dev/null <<EOF
# 允许tronweb用户控制tron-collision服务
tronweb ALL=(ALL) NOPASSWD: /usr/bin/systemctl start tron-collision
tronweb ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop tron-collision
tronweb ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart tron-collision
tronweb ALL=(ALL) NOPASSWD: /usr/bin/systemctl status tron-collision
tronweb ALL=(ALL) NOPASSWD: /usr/bin/systemctl is-active tron-collision
tronweb ALL=(ALL) NOPASSWD: /usr/bin/systemctl is-enabled tron-collision
# 允许tronweb用户使用sudo命令
tronweb ALL=(ALL) NOPASSWD: /usr/bin/sudo
EOF

# 设置SELinux上下文（如果启用）
if getenforce 2>/dev/null | grep -q "Enforcing"; then
    echo "🔐 配置SELinux..."
    sudo setsebool -P httpd_can_network_connect 1
    sudo semanage port -a -t http_port_t -p tcp 5168 2>/dev/null || true
    sudo semanage fcontext -a -t bin_t "/opt/tron-web-monitor/venv/bin/python" 2>/dev/null || true
    sudo restorecon -R /opt/tron-web-monitor/ 2>/dev/null || true
    echo "✅ SELinux配置完成"
fi

# 重新加载systemd
echo "🔄 重新加载systemd..."
sudo systemctl daemon-reload

# 启用Web监控服务
echo "🎯 启用Web监控服务..."
sudo systemctl enable tron-web-monitor

# 获取服务器IP地址
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🎉 Web监控界面安装完成！"
echo ""
echo "═══════════════════════════════════════"
echo "📋 Web监控服务管理:"
echo "───────────────────────────────────────"
echo "  启动Web监控: sudo systemctl start tron-web-monitor"
echo "  停止Web监控: sudo systemctl stop tron-web-monitor"
echo "  查看状态:   sudo systemctl status tron-web-monitor"
echo "  查看日志:   sudo journalctl -u tron-web-monitor -f"
echo ""
echo "🌐 访问地址:"
echo "───────────────────────────────────────"
echo "  本地访问: http://localhost:168"
echo "  远程访问: http://$SERVER_IP:168"
echo "  (确保防火墙已开放168端口)"
echo ""
echo "🔧 重要提醒:"
echo "───────────────────────────────────────"
echo "  1. Web监控界面默认监听所有IP (0.0.0.0:168)"
echo "  2. 请确保防火墙设置仅允许信任的IP访问"
echo "  3. 生产环境建议配置反向代理和HTTPS"
echo "  4. Web界面可以控制TRON碰撞服务的启停"
echo ""
echo "🚀 现在可以启动Web监控服务:"
echo "   sudo systemctl start tron-web-monitor"
echo ""
echo "📱 然后在浏览器中访问: http://$SERVER_IP:168"
echo "═══════════════════════════════════════"
