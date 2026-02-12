#!/bin/bash

# 获取当前脚本所在目录
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "正在停止 VPS 代理服务..."

# 1. 停止 SSH 隧道
./vps_tunnel.sh stop

# 2. 自动取消系统代理 (针对 Wi-Fi)
#如果你使用的是有线网络，请把 "Wi-Fi" 改为 "Ethernet" 或 "USB 10/100/1000 LAN"
networksetup -setautoproxyurl "Wi-Fi" ""
networksetup -setautoproxystate "Wi-Fi" off
echo "系统代理已自动取消。"

echo "服务已全部停止。"
# 保持窗口打开 3 秒
sleep 3
