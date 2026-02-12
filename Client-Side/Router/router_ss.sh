#!/bin/sh

# ==============================================================================
# 路由器 Shadowsocks 客户端启动脚本 (OpenWrt/Ash)
# ==============================================================================
#
# 此脚本用于在 OpenWrt 路由器上启动 ss-local 进程，作为 SOCKS5 代理。
#
# 依赖:
#   opkg update
#   opkg install shadowsocks-libev-ss-local
#
# 配置:
#   请修改下面的 SERVER_IP, SERVER_PORT, PASSWORD, METHOD
#
# ==============================================================================

# ----------- 配置加载模块 -----------
# 尝试读取 config.ini (位于上一级目录的上一级)
CONFIG_FILE="../../config.ini"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 未找到配置文件 $CONFIG_FILE"
    echo "请确保 config.ini 位于项目根目录，并且内容正确。"
    exit 1
fi

# 从 config.ini 读取变量
SERVER_IP=$(grep "^VPS_HOST=" "$CONFIG_FILE" | cut -d'=' -f2)
SERVER_PORT=$(grep "^SS_PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
PASSWORD=$(grep "^SS_PASSWORD=" "$CONFIG_FILE" | cut -d'=' -f2)
METHOD=$(grep "^SS_METHOD=" "$CONFIG_FILE" | cut -d'=' -f2)
LOCAL_PORT=$(grep "^LOCAL_PORT=" "$CONFIG_FILE" | cut -d'=' -f2)

# 验证必填项
if [ -z "$SERVER_IP" ] || [ "$SERVER_IP" == "YOUR_VPS_IP" ]; then
    echo "错误: 请先打开 VPS-Service/config.ini 并填入你的 VPS_HOST (IP地址)！"
    exit 1
fi
if [ -z "$PASSWORD" ] || [ "$PASSWORD" == "YOUR_PASSWORD" ]; then
    echo "错误: 请先配置 config.ini 中的 SS_PASSWORD！(运行服务端安装脚本可获取)"
    exit 1
fi
# =================================================

# 检查是否安装了 ss-local
if ! command -v ss-local >/dev/null 2>&1; then
    echo "错误: 未找到 ss-local 命令！"
    echo "请运行: opkg update && opkg install shadowsocks-libev-ss-local"
    exit 1
fi

# 停止旧进程
killall ss-local 2>/dev/null

echo "正在启动 Shadowsocks 客户端..."
echo "服务器: $SERVER_IP:$SERVER_PORT"
echo "本地端口: $LOCAL_PORT"
echo "加密方式: $METHOD"

# 启动 ss-local
# -s: Server Address
# -p: Server Port
# -k: Password
# -m: Method
# -l: Local Port
# -t: Timeout
# -u: Enable UDP Relay
# -f: Pid File
ss-local -s "$SERVER_IP" 
         -p "$SERVER_PORT" 
         -k "$PASSWORD" 
         -m "$METHOD" 
         -l "$LOCAL_PORT" 
         -t "$TIMEOUT" 
         -u 
         -f /var/run/ss-local.pid 
         >/dev/null 2>&1 &

sleep 2

# 检查进程是否运行
if pgrep ss-local >/dev/null; then
    echo "Shadowsocks 客户端启动成功！"
    echo "SOCKS5 代理已监听: 0.0.0.0:$LOCAL_PORT"
    echo "提示: 现在你可以将局域网内的设备 (电脑/手机) 代理设置为路由器的 IP:$LOCAL_PORT"
else
    echo "启动失败！请检查配置或日志。"
    exit 1
fi
