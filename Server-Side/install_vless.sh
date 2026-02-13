#!/bin/bash

# ==============================================================================
# Xray (VLESS + Reality) 安装脚本
# ==============================================================================
#
# 此脚本用于在你的 VPS 上一键安装 Xray 服务端，并配置 VLESS + Reality 协议。
#
# 特点:
# 1. 无需域名 (使用 Reality 偷取目标网站证书)。
# 2. 极度隐蔽 (流量伪装成访问 Microsoft/Apple 等大厂)。
# 3. 自动生成 vless:// 分享链接。
#
# 使用方法:
# 1. 上传此脚本到 VPS。
# 2. chmod +x install_vless.sh
# 3. ./install_vless.sh
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
PORT=443
DEST_SITE="www.microsoft.com:443"
SERVER_NAMES='["www.microsoft.com","www.microsoft.com"]'

# 获取端口配置
echo -e "${YELLOW}请输入 VLESS 服务端口 [1-65535] (默认: 443):${PLAIN}"
read -r INPUT_PORT
if [[ -n "$INPUT_PORT" ]]; then
  if [[ "$INPUT_PORT" -ge 1 && "$INPUT_PORT" -le 65535 ]]; then
    PORT="$INPUT_PORT"
  else
    echo -e "${RED}端口输入错误，将使用默认端口 443${PLAIN}"
  fi
fi
echo -e "${GREEN}当前使用端口: ${PORT}${PLAIN}"

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
    yum install -y wget curl vim net-tools jq
  else
    apt-get update
    apt-get install -y wget curl vim net-tools jq
  fi
}

# 安装 Xray
install_xray() {
  echo -e "${GREEN}正在安装 Xray-core...${PLAIN}"
  # 使用官方安装脚本
  if ! bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; then
    echo -e "${RED}Xray 安装失败！请检查网络连接。${PLAIN}"
    exit 1
  fi
}

# 生成配置
config_xray() {
  echo -e "${GREEN}正在生成 VLESS-Reality 配置文件...${PLAIN}"
  
  # 生成 UUID
  UUID=$(/usr/local/bin/xray uuid)
  
  # 生成 KeyPair
  KEYS=$(/usr/local/bin/xray x25519)
  PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
  PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')
  
  # 生成 ShortId (随便生成一个)
  SHORT_ID=$(openssl rand -hex 4)

  # 写入配置文件
  cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$DEST_SITE",
          "xver": 0,
          "serverNames": $SERVER_NAMES,
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF
}

# 配置防火墙
config_firewall() {
  echo -e "${GREEN}正在配置防火墙开放端口 $PORT...${PLAIN}"
  if [[ "$OS" == "centos" ]]; then
    systemctl start firewalld
    systemctl enable firewalld
    firewall-cmd --zone=public --add-port="$PORT"/tcp --permanent
    firewall-cmd --reload
  else
    ufw allow "$PORT"/tcp
    # 如果 ufw 没开，不需要强行开
  fi
}

# 开启 BBR 加速
enable_bbr() {
  echo -e "${GREEN}正在检查 BBR 加速状态...${PLAIN}"
  if grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf && grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo -e "${GREEN}BBR 已开启，跳过。${PLAIN}"
  else
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "${GREEN}BBR 开启成功！${PLAIN}"
  fi
}

# 配置服务保活 (Systemd Keepalive)
config_keepalive() {
  # 创建 override 目录
  mkdir -p /etc/systemd/system/xray.service.d
  
  # 写入 override 配置：失败自动重启，间隔 5 秒
  cat > /etc/systemd/system/xray.service.d/override.conf <<EOF
[Service]
Restart=on-failure
RestartSec=5s
EOF
  
  # 重载配置
  systemctl daemon-reload
  echo -e "${GREEN}已配置 Xray 服务自动重启 (保活)。${PLAIN}"
}

# 重启服务 (带重试机制)
restart_xray() {
  echo -e "${GREEN}正在启动 Xray 服务...${PLAIN}"
  config_keepalive
  
  MAX_RETRIES=3
  COUNT=0
  
  while [ $COUNT -lt $MAX_RETRIES ]; do
    systemctl restart xray
    systemctl enable xray >/dev/null 2>&1
    sleep 2
    
    if systemctl is-active --quiet xray; then
      echo -e "${GREEN}Xray 服务启动成功！${PLAIN}"
      return 0
    else
      echo -e "${RED}启动失败，正在尝试重试 ($((COUNT+1))/$MAX_RETRIES)...${PLAIN}"
      # 尝试输出最后几行日志帮助调试
      journalctl -u xray --no-pager -n 10
      COUNT=$((COUNT+1))
      sleep 3
    fi
  done
  
  echo -e "${RED}错误: Xray 服务启动连续失败，请检查配置文件或端口占用。${PLAIN}"
  exit 1
}

# 显示连接信息
show_info() {
  IP=$(curl -s http://ipv4.icanhazip.com)
  
  # 构造 vless:// 链接
  # 格式: vless://uuid@ip:port?security=reality&encryption=none&pbk=public_key&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=sni&sid=short_id#备注
  
  SNI="www.microsoft.com"
  LINK="vless://$UUID@$IP:$PORT?security=reality&encryption=none&pbk=$PUBLIC_KEY&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=$SNI&sid=$SHORT_ID#VPS-Reality"

  echo -e ""
  echo -e "==================================================="
  echo -e "${GREEN}VLESS-Reality 安装完成！${PLAIN}"
  echo -e "==================================================="
  echo -e "地址 (Address): ${YELLOW}$IP${PLAIN}"
  echo -e "端口 (Port)   : ${YELLOW}$PORT${PLAIN}"
  echo -e "用户 ID (UUID): ${YELLOW}$UUID${PLAIN}"
  echo -e "流控 (Flow)   : ${YELLOW}xtls-rprx-vision${PLAIN}"
  echo -e "加密 (Method) : ${YELLOW}none${PLAIN}"
  echo -e "网络 (Network): ${YELLOW}tcp${PLAIN}"
  echo -e "伪装 (Type)   : ${YELLOW}none${PLAIN}"
  echo -e "SNI           : ${YELLOW}$SNI${PLAIN}"
  echo -e "公钥 (Pbk)    : ${YELLOW}$PUBLIC_KEY${PLAIN}"
  echo -e "ShortId       : ${YELLOW}$SHORT_ID${PLAIN}"
  echo -e "==================================================="
  echo -e "${GREEN}VLESS 链接 (复制导入客户端):${PLAIN}"
  echo -e "${YELLOW}$LINK${PLAIN}"
  echo -e "==================================================="
  echo -e "${RED}【重要提示】${PLAIN}"
  echo -e "1. 请去云厂商控制台防火墙/安全组开放 ${YELLOW}TCP $PORT${PLAIN} 端口。"
  echo -e "2. 客户端推荐使用 v2rayN(Win), V2RayXS(Mac), v2rayNG(Android), Shadowrocket(iOS)。"
}

# 主流程
get_os
install_dependencies
enable_bbr
install_xray
config_xray
config_firewall
restart_xray
show_info
