#!/bin/bash

echo "🔐 修复tronweb用户sudo权限"
echo "════════════════════════════════════════"

echo "📋 问题：tronweb用户无法使用sudo命令"
echo "🔧 解决方案：更新sudoers配置"
echo ""

# 1. 检查当前sudoers配置
echo "🔍 检查当前sudoers配置..."
if [ -f "/etc/sudoers.d/tronweb" ]; then
    echo "当前配置："
    cat /etc/sudoers.d/tronweb
    echo ""
else
    echo "❌ 未找到tronweb sudoers配置"
fi

# 2. 备份现有配置
echo "💾 备份现有配置..."
sudo cp /etc/sudoers.d/tronweb /etc/sudoers.d/tronweb.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# 3. 更新sudoers配置
echo "🔧 更新sudoers配置..."
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

# 4. 验证配置语法
echo "🧪 验证sudoers配置语法..."
if sudo visudo -c -f /etc/sudoers.d/tronweb; then
    echo "✅ sudoers配置语法正确"
else
    echo "❌ sudoers配置语法错误"
    echo "恢复备份配置..."
    sudo cp /etc/sudoers.d/tronweb.backup.$(date +%Y%m%d_%H%M%S) /etc/sudoers.d/tronweb 2>/dev/null || true
    exit 1
fi

# 5. 测试sudo权限
echo "🧪 测试tronweb用户sudo权限..."
echo "测试systemctl命令："
sudo -u tronweb sudo systemctl status tron-collision >/dev/null 2>&1 && echo "✅ systemctl权限正常" || echo "❌ systemctl权限失败"

echo "测试sudo命令："
sudo -u tronweb sudo whoami 2>/dev/null | grep -q root && echo "✅ sudo权限正常" || echo "❌ sudo权限失败"

# 6. 重启Web监控服务
echo "🔄 重启Web监控服务..."
sudo systemctl restart tron-web-monitor
sleep 3

if systemctl is-active --quiet tron-web-monitor; then
    echo "✅ Web监控服务重启成功"
else
    echo "❌ Web监控服务重启失败"
    sudo journalctl -u tron-web-monitor --no-pager -n 5
fi

echo ""
echo "🎉 sudo权限修复完成！"
echo "════════════════════════════════════════"
echo "📱 现在可以测试Web界面重启按钮："
echo "   访问: https://tron.zhr.asia"
echo "   点击: 重启按钮"
echo "   应该显示: 服务restart成功！"
echo ""
echo "🔧 如果仍有问题，检查："
echo "   - sudo -u tronweb sudo systemctl status tron-collision"
echo "   - sudo journalctl -u tron-web-monitor -f"
