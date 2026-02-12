#!/bin/bash

# ==============================================================================
# VPS SSH Tunnel Manager
# ==============================================================================
#
# 这个脚本用于通过SSH创建一个SOCKS5代理隧道，帮助你安全地浏览互联网。
#
# 使用方法:
# 1. 填入下面的 VPS_USER, VPS_HOST, 和 LOCAL_PORT 变量。
# 2. 在终端中给脚本添加执行权限: chmod +x vps_tunnel.sh
# 3. 启动隧道: ./vps_tunnel.sh start
# 4. 停止隧道: ./vps_tunnel.sh stop
# 5. 查看状态: ./vps_tunnel.sh status
#
# ==============================================================================

# ----------- 配置加载模块 -----------
# 尝试读取上级目录的 config.ini
CONFIG_FILE="../../config.ini"
if [ -f "$CONFIG_FILE" ]; then
    # 读取配置文件，忽略注释和空行
    # 使用 grep 和 sed 提取变量，避免直接 source 带来的安全风险和路径问题
    VPS_USER=$(grep "^VPS_USER=" "$CONFIG_FILE" | cut -d'=' -f2)
    VPS_HOST=$(grep "^VPS_HOST=" "$CONFIG_FILE" | cut -d'=' -f2)
    LOCAL_PORT=$(grep "^LOCAL_PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
else
    echo "错误: 未找到配置文件 $CONFIG_FILE"
    echo "请确保 config.ini 位于项目根目录，并且内容正确。"
    exit 1
fi

# 检查必要变量
if [ "$VPS_HOST" == "YOUR_VPS_IP" ] || [ -z "$VPS_HOST" ]; then
    echo "错误: 请先打开 VPS-Service/config.ini 并填入你的 VPS_HOST (IP地址)！"
    exit 1
fi
# =================================================

# 控制文件的路径，用于管理后台连接
CONTROL_SOCK="/tmp/ssh_tunnel_${VPS_USER}_${VPS_HOST}.sock"

# 检查SSH master进程是否在运行
is_running() {
    ssh -O check -S "$CONTROL_SOCK" -l "$VPS_USER" "$VPS_HOST" >/dev/null 2>&1
}

# 启动SSH隧道
start_tunnel() {
    if is_running; then
        echo "隧道已经在运行中。"
        return 1
    fi

    echo "正在启动SSH隧道..."
    # -f: 在后台运行
    # -N: 不执行远程命令，仅用于端口转发
    # -D: 指定动态端口转发 (SOCKS代理)
    # -M: 创建一个master连接，以便后续可以控制它 (例如停止)
    # -S: 指定控制socket的路径
    # -C: 压缩数据
    # -q: 安静模式
    local SSH_CMD="ssh -f -N -C -q -M -S $CONTROL_SOCK -D $LOCAL_PORT"
    if [ -n "$SSH_KEY_PATH" ]; then
        SSH_CMD="$SSH_CMD -i $SSH_KEY_PATH"
    fi
    
    $SSH_CMD "${VPS_USER}@${VPS_HOST}"

    if is_running; then
        echo "隧道已成功启动！"
        echo "SOCKS5 代理正在监听: 127.0.0.1:${LOCAL_PORT}"
        echo "请配置你的浏览器或系统使用此代理。"
    else
        echo "错误：启动隧道失败。请检查你的VPS信息和网络连接。"
        return 1
    fi
}

# 停止SSH隧道
stop_tunnel() {
    if ! is_running; then
        echo "隧道当前未运行。"
        return 1
    fi

    echo "正在停止SSH隧道..."
    ssh -O exit -S "$CONTROL_SOCK" -l "$VPS_USER" "$VPS_HOST"
    if ! is_running; then
        echo "隧道已成功停止。"
    else
        echo "错误：停止隧道失败。"
        return 1
    fi
}

# 检查状态
check_status() {
    if is_running; then
        echo "隧道正在运行中。"
        echo "SOCKS5 代理: 127.0.0.1:${LOCAL_PORT}"
    else
        echo "隧道当前未运行。"
    fi
}


# 主逻辑
case "$1" in
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    status)
        check_status
        ;;
    *)
        echo "用法: $0 {start|stop|status}"
        exit 1
        ;;
esac

exit 0
