#!/bin/bash

# ==============================================================================
# VPS 客户端统一连接工具 (macOS / Linux)
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config.ini"

# 检查配置文件是否存在
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}错误: 找不到配置文件 $CONFIG_FILE${PLAIN}"
    echo -e "请先复制 config.ini.example 为 config.ini 并填写配置。"
    exit 1
fi

# 读取配置文件 (忽略注释和空行)
source <(grep -vE "^#|^$" "$CONFIG_FILE")

# 检查配置是否填写
if [[ "$VPS_HOST" == "YOUR_VPS_IP" ]]; then
    echo -e "${RED}错误: 请先编辑 config.ini 填入 VPS IP 地址！${PLAIN}"
    exit 1
fi

# ==============================================================================
# 功能函数
# ==============================================================================

# 检查并安装依赖 (针对 SS 模式)
check_ss_dependency() {
    if ! command -v ss-local &> /dev/null; then
        echo -e "${YELLOW}未检测到 Shadowsocks 客户端 (ss-local)。${PLAIN}"
        read -p "是否尝试自动安装? [y/N] " install_choice
        case "$install_choice" in
            [yY][eE][sS]|[yY])
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS
                    if command -v brew &> /dev/null; then
                        echo -e "${GREEN}正在使用 Homebrew 安装 shadowsocks-libev...${PLAIN}"
                        brew install shadowsocks-libev
                    else
                        echo -e "${RED}错误: 未安装 Homebrew，无法自动安装。请手动安装: brew install shadowsocks-libev${PLAIN}"
                        return 1
                    fi
                else
                    # Linux
                    if command -v apt-get &> /dev/null; then
                        echo -e "${GREEN}正在使用 apt 安装 shadowsocks-libev...${PLAIN}"
                        sudo apt-get update && sudo apt-get install -y shadowsocks-libev
                    elif command -v yum &> /dev/null; then
                        echo -e "${GREEN}正在使用 yum 安装 shadowsocks-libev...${PLAIN}"
                        sudo yum install -y shadowsocks-libev
                    else
                        echo -e "${RED}错误: 无法识别包管理器，请手动安装 shadowsocks-libev。${PLAIN}"
                        return 1
                    fi
                fi
                ;;
            *)
                echo -e "${YELLOW}已取消安装。无法使用 SS 模式。${PLAIN}"
                return 1
                ;;
        esac
    fi
    return 0
}

# 启动 SSH 隧道
start_ssh_tunnel() {
    echo -e "${GREEN}正在启动 SSH 隧道...${PLAIN}"
    echo -e "目标服务器: ${YELLOW}$VPS_USER@$VPS_HOST${PLAIN}"
    echo -e "本地端口: ${YELLOW}$LOCAL_PORT${PLAIN}"
    echo -e "请在提示时输入 VPS 登录密码。"
    
    # -N: 不执行远程命令
    # -D: 动态端口转发 (SOCKS5)
    # -f: 后台运行 (这里不加 -f，为了让用户看到输出和保持连接)
    # -C: 压缩数据
    ssh -C -N -D 127.0.0.1:$LOCAL_PORT $VPS_USER@$VPS_HOST
}

# 启动 Shadowsocks
start_ss_client() {
    if ! check_ss_dependency; then
        return
    fi

    echo -e "${GREEN}正在启动 Shadowsocks 客户端...${PLAIN}"
    echo -e "服务器: ${YELLOW}$VPS_HOST:$SS_PORT${PLAIN}"
    echo -e "本地端口: ${YELLOW}$LOCAL_PORT${PLAIN}"
    echo -e "加密方式: ${YELLOW}$SS_METHOD${PLAIN}"

    # ss-local 命令
    ss-local -s "$VPS_HOST" 
             -p "$SS_PORT" 
             -k "$SS_PASSWORD" 
             -m "$SS_METHOD" 
             -l "$LOCAL_PORT" 
             -b "127.0.0.1" 
             -v
}

# ==============================================================================
# 主菜单
# ==============================================================================

clear
echo -e "==================================================="
echo -e "${BLUE}VPS 客户端统一连接工具${PLAIN}"
echo -e "==================================================="
echo -e "当前配置:"
echo -e "  VPS IP: ${YELLOW}$VPS_HOST${PLAIN}"
echo -e "  本地端口: ${YELLOW}$LOCAL_PORT${PLAIN}"
echo -e "==================================================="
echo -e "1. ${GREEN}启动 SSH 隧道模式${PLAIN} (推荐，无需安装)"
echo -e "2. ${YELLOW}启动 Shadowsocks 模式${PLAIN} (需安装 ss-local，更稳定)"
echo -e "0. 退出"
echo -e "==================================================="

read -p "请输入选项 [1-2]: " choice

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
        echo -e "${RED}无效选项，默认启动 SSH 隧道...${PLAIN}"
        start_ssh_tunnel
        ;;
esac
