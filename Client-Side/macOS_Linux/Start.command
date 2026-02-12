#!/bin/bash

# 获取当前脚本所在目录
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# 尝试让脚本可执行 (以防万一)
chmod +x ./vps_tunnel.sh

echo "正在启动 VPS 代理服务..."

# 1. 启动 SSH 隧道
./vps_tunnel.sh start

# 检查上一条命令是否成功
if [ $? -eq 0 ]; then
    echo "SSH 隧道启动成功！"
    
    # 2. 自动设置系统代理 (针对 Wi-Fi)
    #如果你使用的是有线网络，请把 "Wi-Fi" 改为 "Ethernet" 或 "USB 10/100/1000 LAN"
    networksetup -setautoproxyurl "Wi-Fi" "file://$DIR/proxy.pac"
    echo "系统代理已自动配置为: file://$DIR/proxy.pac"
    
    # 保持窗口打开 5 秒，让用户看到结果
    sleep 5
else
    echo "启动失败，请检查 vps_tunnel.sh 中的配置！"
    # 失败时保持窗口打开，直到用户按下回车
    read -p "按回车键退出..."
fi
