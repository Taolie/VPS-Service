#!/bin/bash

# ==============================================================================
# Shadowsocks-libev 安装脚本 (无需域名)
# ==============================================================================
#
# 此脚本用于在你的 VPS 上一键安装 Shadowsocks 服务端。
#
# 功能:
# 1. 自动识别系统 (Debian/Ubuntu/CentOS)。
# 2. 安装 shadowsocks-libev。
# 3. 随机生成端口和密码 (也可以自定义)。
# 4. 配置防火墙 (ufw/firewalld)。
# 5. 生成客户端连接信息 (ss:// 链接)。
#
# 使用方法:
# 1. 上传此脚本到 VPS。
# 2. chmod +x install_ss.sh
# 3. ./install_ss.sh
#
# ==============================================================================

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查是否为 root 用户
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 用户运行此脚本！${PLAIN}" && exit 1

# 默认配置
SS_PORT=$(shuf -i 10000-60000 -n 1)
SS_PASSWORD=$(openssl rand -base64 16)
SS_METHOD="chacha20-ietf-poly1305"
CONFIG_FILE="/etc/shadowsocks-libev/config.json"

# 获取系统版本
get_os() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        OS="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        OS="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        OS="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        OS="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        OS="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        OS="centos"
    else
        echo -e "${RED}错误: 不支持的操作系统！${PLAIN}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${GREEN}正在更新系统并安装依赖...${PLAIN}"
    if [[ "$OS" == "centos" ]]; then
        yum install -y epel-release
        yum update -y
        yum install -y wget curl vim net-tools
    else
        apt-get update
        apt-get install -y wget curl vim net-tools ufw
    fi
}

# 安装 Shadowsocks
install_ss() {
    echo -e "${GREEN}正在安装 Shadowsocks-libev...${PLAIN}"
    if [[ "$OS" == "centos" ]]; then
        # CentOS 8/Stream 可能需要 snap 或者源码编译，这里暂时只支持 7
        yum install -y shadowsocks-libev
    else
        apt-get install -y shadowsocks-libev
    fi

    if ! command -v ss-server &>/dev/null; then
        echo -e "${RED}安装失败！请检查网络或源配置。${PLAIN}"
        exit 1
    fi
}

# 配置 Shadowsocks
config_ss() {
    echo -e "${GREEN}正在生成配置文件...${PLAIN}"
    cat >$CONFIG_FILE <<EOF
{
    "server":"0.0.0.0",
    "server_port":$SS_PORT,
    "password":"$SS_PASSWORD",
    "timeout":300,
    "method":"$SS_METHOD",
    "fast_open":true,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp"
}
EOF
}

# 配置防火墙
config_firewall() {
    echo -e "${GREEN}正在配置防火墙开放端口 $SS_PORT...${PLAIN}"
    if [[ "$OS" == "centos" ]]; then
        systemctl start firewalld
        systemctl enable firewalld
        firewall-cmd --zone=public --add-port="$SS_PORT"/tcp --permanent
        firewall-cmd --zone=public --add-port="$SS_PORT"/udp --permanent
        firewall-cmd --reload
    else
        ufw allow "$SS_PORT"/tcp
        ufw allow "$SS_PORT"/udp
        # 如果 ufw 没开，不需要强行开，防止把 ssh 关了
    fi
}

# 启动服务
start_ss() {
    echo -e "${GREEN}正在启动 Shadowsocks 服务...${PLAIN}"
    systemctl enable shadowsocks-libev
    systemctl restart shadowsocks-libev

    if systemctl status shadowsocks-libev | grep -q "active (running)"; then
        echo -e "${GREEN}Shadowsocks 服务启动成功！${PLAIN}"
    else
        echo -e "${RED}Shadowsocks 服务启动失败！请查看日志 systemctl status shadowsocks-libev${PLAIN}"
        exit 1
    fi
}

# 生成连接信息
show_info() {
    # 获取公网IP
    IP=$(curl -s http://ipv4.icanhazip.com)

    # 生成 ss:// 链接 (Base64编码: method:password@ip:port)
    SS_LINK_RAW="$SS_METHOD:$SS_PASSWORD@$IP:$SS_PORT"
    SS_LINK="ss://$(echo -n "$SS_LINK_RAW" | base64)"

    echo -e ""
    echo -e "==================================================="
    echo -e "${GREEN}Shadowsocks 安装完成！${PLAIN}"
    echo -e "==================================================="
    echo -e "服务器 IP  : ${YELLOW}$IP${PLAIN}"
    echo -e "端口 (Port): ${YELLOW}$SS_PORT${PLAIN}"
    echo -e "密码 (Pwd) : ${YELLOW}$SS_PASSWORD${PLAIN}"
    echo -e "加密 (Method): ${YELLOW}$SS_METHOD${PLAIN}"
    echo -e "==================================================="
    echo -e "${GREEN}SS 链接 (复制导入客户端):${PLAIN}"
    echo -e "${YELLOW}$SS_LINK${PLAIN}"
    echo -e "==================================================="
    echo -e "${RED}【重要提示】请务必执行以下操作，否则无法连接：${PLAIN}"
    echo -e "1. 登录您的云服务器控制台 (阿里云/腾讯云/AWS等)。"
    echo -e "2. 找到 [安全组] 或 [防火墙] 设置。"
    echo -e "3. 添加一条规则：允许 [TCP+UDP] 协议，端口 [${YELLOW}$SS_PORT${PLAIN}]。"
    echo -e "   (脚本已自动为您开放了 VPS 内部的防火墙，但无法操作云平台的安全组)"
}

# 主流程
get_os
install_dependencies
install_ss
config_ss
config_firewall
start_ss
show_info
