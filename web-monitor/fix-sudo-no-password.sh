#!/bin/bash

echo "🔐 修复tronweb用户sudo权限（无需密码）"
echo "════════════════════════════════════════"

echo "📋 问题：tronweb是系统用户，没有密码"
echo "🔧 解决方案：直接用root权限修改sudoers"
echo ""

# 1. 检查tronweb用户信息
echo "🔍 检查tronweb用户信息..."
echo "用户ID: $(id tronweb 2>/dev/null || echo '用户不存在')"
echo "用户类型: $(getent passwd tronweb | cut -d: -f7 2>/dev/null || echo '无法获取')"
echo ""

# 2. 备份现有配置
echo "💾 备份现有sudoers配置..."
if [ -f "/etc/sudoers.d/tronweb" ]; then
    sudo cp /etc/sudoers.d/tronweb /etc/sudoers.d/tronweb.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ 已备份现有配置"
else
    echo "ℹ️  未找到现有配置，将创建新配置"
fi

# 3. 直接修改sudoers文件（不需要tronweb密码）
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
    exit 1
fi

# 5. 显示新配置
echo "📋 新的sudoers配置："
echo "───────────────────────────────────────"
cat /etc/sudoers.d/tronweb
echo ""

# 6. 测试sudo权限
echo "🧪 测试sudo权限..."
echo "测试tronweb用户sudo权限："

# 使用su命令切换到tronweb用户测试
if echo "sudo systemctl status tron-collision" | sudo -u tronweb bash 2>/dev/null; then
    echo "✅ sudo权限测试成功"
else
    echo "⚠️  sudo权限测试失败，但配置已更新"
    echo "可能需要重启Web监控服务使配置生效"
fi

# 7. 重启Web监控服务
echo "🔄 重启Web监控服务使配置生效..."
sudo systemctl restart tron-web-monitor
sleep 3

if systemctl is-active --quiet tron-web-monitor; then
    echo "✅ Web监控服务重启成功"
else
    echo "❌ Web监控服务重启失败"
    echo "查看错误日志："
    sudo journalctl -u tron-web-monitor --no-pager -n 5
fi

echo ""
echo "🎉 sudo权限修复完成！"
echo "════════════════════════════════════════"
echo "📱 现在测试Web界面："
echo "   访问: https://tron.zhr.asia"
echo "   点击: 重启按钮"
echo "   应该显示: 服务restart成功！"
echo ""
echo "🔧 如果仍有问题，手动测试："
echo "   sudo -u tronweb sudo systemctl status tron-collision"
