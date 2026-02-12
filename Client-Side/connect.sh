#!/bin/sh

# ==============================================================================
# VPS 客户端统一连接工具 (Universal: macOS / Linux / OpenWrt)
# ==============================================================================

# 颜色定义 (兼容 sh)
if [ -t 1 ]; then
    RED=$(printf '\033[0;31m')
    GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[0;33m')
    BLUE=$(printf '\033[0;34m')
    PLAIN=$(printf '\033[0m')
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    PLAIN=""
fi

# 获取脚本所在目录的绝对路径 (兼容 sh)
SCRIPT_DIR=$(
    cd "$(dirname "$0")" || exit
    pwd
)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$PROJECT_ROOT/config.ini"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "${RED}错误: 找不到配置文件 $CONFIG_FILE${PLAIN}"
    echo "请先复制 config.ini.example 为 config.ini 并填写配置。"
    exit 1
fi

# 读取配置文件 (兼容 sh 的解析方式)
# 逐行读取，去除注释和空行，并 export 变量
while IFS='=' read -r key value; do
    # 跳过注释 (# 开头) 和空行
    case "$key" in
    \#* | "") continue ;;
    esac
    # 去除 value 可能存在的首尾空格 (简单处理)
    # export 变量
    export "$key=$value"
done <"$CONFIG_FILE"

# 检查配置是否填写
if [ "$VPS_HOST" = "YOUR_VPS_IP" ]; then
    echo "${RED}错误: 请先编辑 config.ini 填入 VPS IP 地址！${PLAIN}"
    exit 1
fi

# ==============================================================================
# 环境检测与适配
# ==============================================================================

# 检测是否为 OpenWrt
IS_OPENWRT=0
if [ -f /etc/openwrt_release ]; then
    IS_OPENWRT=1
fi

# 设置监听地址
# 普通电脑: 127.0.0.1 (仅本机)
# 路由器: 0.0.0.0 (局域网共享)
if [ "$IS_OPENWRT" -eq 1 ]; then
    BIND_ADDR="0.0.0.0"
else
    BIND_ADDR="127.0.0.1"
fi

# ==============================================================================
# 功能函数
# ==============================================================================

# 检查并安装依赖
check_dependency() {
    CMD_NAME="$1" # ssh 或 ss-local

    if command -v "$CMD_NAME" >/dev/null 2>&1; then
        return 0
    fi

    echo "${YELLOW}未检测到命令: $CMD_NAME${PLAIN}"
    printf "是否尝试自动安装? [y/N] "
    read -r install_choice

    case "$install_choice" in
    [yY]*)
        if [ "$IS_OPENWRT" -eq 1 ]; then
            echo "${GREEN}正在使用 opkg 安装 shadowsocks-libev-ss-local...${PLAIN}"
            opkg update
            opkg install shadowsocks-libev-ss-local
        elif command -v brew >/dev/null 2>&1; then
            echo "${GREEN}正在使用 Homebrew 安装...${PLAIN}"
            brew install shadowsocks-libev
        elif command -v apt-get >/dev/null 2>&1; then
            echo "${GREEN}正在使用 apt 安装...${PLAIN}"
            if [ "$(id -u)" -ne 0 ]; then
                sudo apt-get update && sudo apt-get install -y shadowsocks-libev
            else
                apt-get update && apt-get install -y shadowsocks-libev
            fi
        elif command -v yum >/dev/null 2>&1; then
            echo "${GREEN}正在使用 yum 安装...${PLAIN}"
            if [ "$(id -u)" -ne 0 ]; then
                sudo yum install -y shadowsocks-libev
            else
                yum install -y shadowsocks-libev
            fi
        else
            echo "${RED}错误: 无法识别包管理器，请手动安装。${PLAIN}"
            return 1
        fi
        ;;
    *)
        echo "${YELLOW}已取消安装。${PLAIN}"
        return 1
        ;;
    esac

    # 再次检查
    if command -v "$CMD_NAME" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 启动 SSH 隧道
start_ssh_tunnel() {
    if ! check_dependency "ssh"; then return; fi

    echo "${GREEN}正在启动 SSH 隧道...${PLAIN}"
    echo "目标服务器: ${YELLOW}$VPS_USER@$VPS_HOST${PLAIN}"
    echo "本地监听: ${YELLOW}$BIND_ADDR:$LOCAL_PORT${PLAIN}"
    echo "请在提示时输入 VPS 登录密码。"

    # -g: 允许远程主机连接本地转发端口 (如果需要在路由器上开放 SSH 隧道)
    SSH_OPTS="-C -N -D $BIND_ADDR:$LOCAL_PORT"
    if [ "$IS_OPENWRT" -eq 1 ]; then
        # OpenWrt 的 ssh 客户端 (dropbear/openssh) 可能参数略有不同，但通常兼容
        # 如果是 Dropbear ssh，可能不支持 -C (压缩)，视版本而定
        SSH_OPTS="-N -D $BIND_ADDR:$LOCAL_PORT"
    fi

    # SC2029: 忽略此警告，我们确实需要在本地展开变量
    # shellcheck disable=SC2029
    ssh "$SSH_OPTS" "$VPS_USER@$VPS_HOST"
}

# 启动 Shadowsocks
start_ss_client() {
    if ! check_dependency "ss-local"; then return; fi

    echo "${GREEN}正在启动 Shadowsocks 客户端...${PLAIN}"
    echo "服务器: ${YELLOW}$VPS_HOST:$SS_PORT${PLAIN}"
    echo "本地监听: ${YELLOW}$BIND_ADDR:$LOCAL_PORT${PLAIN}"
    echo "加密方式: ${YELLOW}$SS_METHOD${PLAIN}"

    # ss-local 命令
    # 注意: OpenWrt 上的 ss-local 可能没有 -v 详细模式，或者参数行为略有不同
    # 但核心参数 -s -p -k -m -l -b 是一致的

    ss-local -s "$VPS_HOST" \
        -p "$SS_PORT" \
        -k "$SS_PASSWORD" \
        -m "$SS_METHOD" \
        -l "$LOCAL_PORT" \
        -b "$BIND_ADDR" \
        -u \
        -v
}

# ==============================================================================
# 主菜单
# ==============================================================================

clear
echo "==================================================="
echo "${BLUE}VPS 客户端统一连接工具${PLAIN}"
if [ "$IS_OPENWRT" -eq 1 ]; then
    echo "${YELLOW}(检测到 OpenWrt 环境: 已启用局域网共享模式)${PLAIN}"
fi
echo "==================================================="
echo "当前配置:"
echo "  VPS IP: ${YELLOW}$VPS_HOST${PLAIN}"
echo "  本地端口: ${YELLOW}$LOCAL_PORT${PLAIN}"
echo "==================================================="
echo "1. ${GREEN}启动 SSH 隧道模式${PLAIN} (免安装)"
echo "2. ${YELLOW}启动 Shadowsocks 模式${PLAIN} (更稳定)"
echo "0. 退出"
echo "==================================================="

printf "请输入选项 [1-2]: "
read -r choice

case "$choice" in
1)
    start_ssh_tunnel
    ;;
2)
    start_ss_client
    ;;
0)
    exit 0
    ;;
*)
    echo "${RED}无效选项，默认启动 SSH 隧道...${PLAIN}"
    start_ssh_tunnel
    ;;
esac
