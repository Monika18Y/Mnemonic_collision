# 🌐 TRON私钥碰撞工具 - Web监控界面使用指南

## 📋 功能概述

Web监控界面提供了一个美观的浏览器界面，让您可以远程监控Rocky Linux服务器上运行的TRON私钥碰撞工具。

### 🎯 主要功能

- **📊 实时状态监控**: 服务运行状态、系统资源使用情况
- **🎮 服务控制**: 启动、停止、重启碰撞服务
- **📈 统计信息**: 检查总数、发现地址、运行速度
- **📝 实时日志**: 查看碰撞程序的实时输出
- **🏆 发现展示**: 当发现有资产地址时醒目显示
- **⚡ WebSocket实时更新**: 无需刷新页面，数据自动更新

## 🚀 安装部署

### 前置条件

确保已经安装了基础的TRON碰撞服务：
```bash
./install-rocky.sh
```

### 一键安装Web监控

```bash
# 1. 赋予执行权限
chmod +x install-web-monitor.sh

# 2. 运行安装脚本
./install-web-monitor.sh

# 3. 启动Web监控服务
sudo systemctl start tron-web-monitor
```

### 手动安装步骤

如果一键安装遇到问题，可以手动安装：

```bash
# 1. 创建目录
sudo mkdir -p /opt/tron-web-monitor

# 2. 复制文件
sudo cp -r web_monitor.py templates static web-requirements.txt /opt/tron-web-monitor/

# 3. 安装依赖
cd /opt/tron-web-monitor
sudo python3 -m venv venv
sudo ./venv/bin/pip install -r web-requirements.txt

# 4. 创建用户和服务
sudo useradd -r -s /bin/false tronweb
sudo chown -R tronweb:tronweb /opt/tron-web-monitor
sudo systemctl enable tron-web-monitor
sudo systemctl start tron-web-monitor
```

## 🔧 配置说明

### 端口配置

默认端口：**5168**

如需修改端口，编辑 `/opt/tron-web-monitor/web_monitor.py`：
```python
socketio.run(app, host='0.0.0.0', port=5168, debug=False)
```

### 防火墙配置

```bash
# Rocky Linux (firewalld)
sudo firewall-cmd --permanent --add-port=5168/tcp
sudo firewall-cmd --reload

# 查看规则
sudo firewall-cmd --list-ports
```

### 安全配置

Web监控默认监听所有IP地址 (0.0.0.0)，生产环境建议：

1. **限制访问IP**
```bash
# 只允许特定IP访问
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='YOUR_IP' port port=5168 protocol=tcp accept"
sudo firewall-cmd --reload
```

2. **配置反向代理** (推荐使用Nginx)
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://127.0.0.1:168;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 📱 界面使用

### 访问地址

浏览器访问：`http://YOUR_SERVER_IP:168`

### 界面功能说明

#### 1. 📊 状态监控区域
- **服务状态**: 显示TRON碰撞服务是否运行
- **统计信息**: 总检查数、发现地址数、检查速度
- **运行时间**: 程序持续运行时间

#### 2. 🖥️ 系统资源监控
- **CPU使用率**: 实时CPU占用百分比
- **内存使用率**: 内存占用情况
- **磁盘使用率**: 磁盘空间使用情况

#### 3. 🎮 服务控制按钮
- **🟢 启动**: 启动TRON碰撞服务
- **🟡 重启**: 重启服务（解决卡顿问题）
- **🔴 停止**: 停止服务

#### 4. 📝 实时日志查看
- 自动滚动显示最新日志
- 绿色字体显示，仿终端效果
- 点击"刷新"按钮手动更新

#### 5. 🏆 发现地址展示（安全模式）
当发现有资产的地址时，会在页面顶部显示醒目的金色卡片：
- **发现序号**: 标识第几个发现的地址
- **发现时间**: 具体的发现时间戳
- **TRON地址**: 完整的TRON地址（可公开）
- **余额信息**: TRX余额和代币信息
- **🔐 私钥安全保护**: 私钥不会在Web界面显示，只安全保存在服务器文件中

> **安全设计**：为了保护资产安全，私钥信息不会通过网络传输到Web界面。私钥只保存在服务器的 `/opt/tron-collision/non_zero_addresses.txt` 文件中，需要通过SSH登录服务器查看。

### 实时更新机制

界面使用WebSocket技术实现实时更新：
- **连接状态**: 右上角显示连接状态
- **自动更新**: 每5秒自动更新所有数据
- **即时响应**: 操作后立即反馈结果

## 🛠️ 故障排除

### 常见问题

#### 1. 无法访问Web界面
```bash
# 检查服务状态
sudo systemctl status tron-web-monitor

# 检查端口是否开放
sudo ss -tlnp | grep 168

# 检查防火墙
sudo firewall-cmd --list-ports
```

#### 2. 服务控制按钮无效
```bash
# 检查sudo权限配置
sudo cat /etc/sudoers.d/tronweb

# 手动测试权限
sudo -u tronweb sudo systemctl status tron-collision
```

#### 3. 日志不显示
```bash
# 检查日志文件权限
ls -la /opt/tron-collision/logs.txt

# 检查用户组
groups tronweb
```

#### 4. WebSocket连接失败
- 检查防火墙是否阻止WebSocket连接
- 确认浏览器支持WebSocket
- 查看浏览器控制台错误信息

### 日志查看

```bash
# Web监控服务日志
sudo journalctl -u tron-web-monitor -f

# 查看错误日志
sudo journalctl -u tron-web-monitor -p err --since today

# 检查进程
ps aux | grep web_monitor
```

## 📈 性能优化

### 系统资源优化

Web监控服务轻量级，通常占用：
- **内存**: 30-50MB
- **CPU**: 很低（主要是I/O操作）

### 并发访问

Flask-SocketIO支持多用户同时访问，但建议：
- 生产环境使用Gunicorn部署
- 限制同时在线用户数
- 配置适当的超时时间

### 大量日志优化

如果日志文件过大影响性能：
```bash
# 限制日志文件大小
sudo logrotate -f /etc/logrotate.d/tron-collision

# 或手动清理旧日志
sudo truncate -s 0 /opt/tron-collision/logs.txt
```

## 🔒 安全最佳实践

### 🛡️ 私钥安全保护

Web监控系统采用严格的私钥保护机制：

**安全特性**：
- ✅ **零传输**: 私钥信息绝不通过网络传输
- ✅ **零显示**: Web界面永远不显示完整私钥
- ✅ **服务器保存**: 私钥只保存在服务器安全文件中
- ✅ **访问控制**: 只有服务器管理员可以查看私钥

**私钥文件位置**：
```bash
/opt/tron-collision/non_zero_addresses.txt
```

**安全查看私钥**：
```bash
# SSH登录服务器
ssh username@your-server

# 查看发现的地址和私钥（需要sudo权限）
sudo cat /opt/tron-collision/non_zero_addresses.txt

# 查看最新发现
sudo tail -20 /opt/tron-collision/non_zero_addresses.txt

# 安全备份私钥文件
sudo cp /opt/tron-collision/non_zero_addresses.txt /secure/backup/location/
```

**私钥安全建议**：
1. 🔐 **立即备份**: 发现资产后立即安全备份私钥
2. 💾 **多重备份**: 使用加密存储进行多重备份  
3. 🔒 **访问限制**: 严格控制服务器SSH访问权限
4. 📋 **权限检查**: 定期检查私钥文件访问权限
5. 🚀 **快速转移**: 发现资产后尽快转移到安全钱包

1. **网络安全**
   - 使用VPN或专用网络访问
   - 配置IP白名单
   - 使用HTTPS（配置SSL证书）

2. **访问控制**
   - 定期更改访问端口
   - 添加HTTP基础认证
   - 限制会话时间

3. **监控告警**
   - 配置服务异常告警
   - 监控异常访问日志
   - 定期检查系统安全

## 🎨 界面自定义

### 修改主题色彩

编辑 `templates/index.html` 中的CSS：
```css
body {
    background: linear-gradient(135deg, #your-color1 0%, #your-color2 100%);
}
```

### 添加自定义功能

可以在 `web_monitor.py` 中添加新的API端点：
```python
@app.route('/api/custom')
def custom_api():
    return jsonify({'custom': 'data'})
```

## 📞 技术支持

如果遇到问题：

1. **查看日志**: `sudo journalctl -u tron-web-monitor -f`
2. **检查配置**: 确认所有配置文件正确
3. **重启服务**: `sudo systemctl restart tron-web-monitor`
4. **联系支持**: monika18dol@gmail.com

---

**享受您的Web监控体验！** 🎉

记住：成功概率极低，请理性对待，这主要是学习和研究工具。
