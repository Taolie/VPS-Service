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

# 辅助: 检查并获取必要配置
ensure_config() {
  VAR_NAME="$1"
  PROMPT_TEXT="$2"
  # 使用 eval 获取变量值
  eval "CURRENT_VAL=\${$VAR_NAME}"
  
  # 如果变量为空 or 为默认值，则提示输入
  if [ -z "$CURRENT_VAL" ] || [ "$CURRENT_VAL" = "YOUR_VPS_IP" ] || [ "$CURRENT_VAL" = "YOUR_PASSWORD" ]; then
    echo "${YELLOW}$PROMPT_TEXT${PLAIN}"
    read -r INPUT_VAL
    if [ -n "$INPUT_VAL" ]; then
      export "$VAR_NAME=$INPUT_VAL"
    else
      echo "${RED}错误: 参数不能为空！${PLAIN}"
      return 1
    fi
  fi
  return 0
}

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
  
  if ! ensure_config "VPS_HOST" "请输入 VPS IP 地址:"; then return; fi
  if [ -z "$VPS_USER" ]; then VPS_USER="root"; fi

  echo "${GREEN}正在启动 SSH 隧道...${PLAIN}"
  echo "目标服务器: ${YELLOW}$VPS_USER@$VPS_HOST${PLAIN}"
  echo "本地监听: ${YELLOW}$BIND_ADDR:$LOCAL_PORT${PLAIN}"
  echo "请在提示时输入 VPS 登录密码。"

  # -g: 允许远程主机连接本地转发端口 (如果需要在路由器上开放 SSH 隧道)
  SSH_OPTS="-C -N -D $BIND_ADDR:$LOCAL_PORT"
  if [ "$IS_OPENWRT" -eq 1 ]; then
    SSH_OPTS="-N -D $BIND_ADDR:$LOCAL_PORT"
  fi

  # shellcheck disable=SC2029
  ssh "$SSH_OPTS" "$VPS_USER@$VPS_HOST"
}

# 启动 Shadowsocks
start_ss_client() {
  if ! check_dependency "ss-local"; then return; fi

  if ! ensure_config "VPS_HOST" "请输入 VPS IP 地址:"; then return; fi
  if ! ensure_config "SS_PORT" "请输入 Shadowsocks 端口:"; then return; fi
  if ! ensure_config "SS_PASSWORD" "请输入 Shadowsocks 密码:"; then return; fi
  if ! ensure_config "SS_METHOD" "请输入加密方式 (默认 chacha20-ietf-poly1305):"; then return; fi

  echo "${GREEN}正在启动 Shadowsocks 客户端...${PLAIN}"
  echo "服务器: ${YELLOW}$VPS_HOST:$SS_PORT${PLAIN}"
  echo "本地监听: ${YELLOW}$BIND_ADDR:$LOCAL_PORT${PLAIN}"
  echo "加密方式: ${YELLOW}$SS_METHOD${PLAIN}"

  ss-local -s "$VPS_HOST" \
    -p "$SS_PORT" \
    -k "$SS_PASSWORD" \
    -m "$SS_METHOD" \
    -l "$LOCAL_PORT" \
    -b "$BIND_ADDR" \
    -u \
    -v
}

# ------------------------------------------------------------------------------
# VLESS-Reality 客户端逻辑 (增强版: 多节点 + 分流 + 自动代理 + TProxy + 后台)
# ------------------------------------------------------------------------------

# 存储节点的文件
NODES_FILE="$SCRIPT_DIR/nodes.dat"
PID_FILE="$SCRIPT_DIR/xray.pid"
LOG_FILE="$SCRIPT_DIR/xray.log"

# 设置系统代理 (macOS / Linux Gnome/KDE)
set_system_proxy() {
  if [ "$IS_OPENWRT" -eq 1 ]; then return; fi

  # macOS
  if [ "$(uname)" = "Darwin" ]; then
    INTERFACE=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')
    if [ -n "$INTERFACE" ]; then
      SERVICE=$(networksetup -listnetworkserviceorder | grep -B1 "$INTERFACE" | head -n1 | cut -d' ' -f2-)
      if [ -n "$SERVICE" ]; then
        echo "${GREEN}检测到活动网卡: $SERVICE，正在开启系统代理...${PLAIN}"
        networksetup -setsocksfirewallproxy "$SERVICE" 127.0.0.1 "$LOCAL_PORT"
      fi
    fi
  # Linux Gnome
  elif command -v gsettings >/dev/null 2>&1; then
    echo "${GREEN}检测到 Gnome 环境，正在开启系统代理...${PLAIN}"
    gsettings set org.gnome.system.proxy mode 'manual'
    gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
    gsettings set org.gnome.system.proxy.socks port "$LOCAL_PORT"
  # Linux KDE
  elif command -v kwriteconfig5 >/dev/null 2>&1; then
    echo "${GREEN}检测到 KDE 环境，正在开启系统代理...${PLAIN}"
    kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType 1
    kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key socksProxy "socks://127.0.0.1:$LOCAL_PORT"
  fi
}

# 清除系统代理
unset_system_proxy() {
  if [ "$IS_OPENWRT" -eq 1 ]; then return; fi

  # macOS
  if [ "$(uname)" = "Darwin" ]; then
    INTERFACE=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')
    if [ -n "$INTERFACE" ]; then
      SERVICE=$(networksetup -listnetworkserviceorder | grep -B1 "$INTERFACE" | head -n1 | cut -d' ' -f2-)
      if [ -n "$SERVICE" ]; then
        echo ""
        echo "${YELLOW}正在关闭系统代理...${PLAIN}"
        networksetup -setsocksfirewallproxystate "$SERVICE" off
      fi
    fi
  # Linux Gnome
  elif command -v gsettings >/dev/null 2>&1; then
    echo ""
    echo "${YELLOW}正在关闭 Gnome 系统代理...${PLAIN}"
    gsettings set org.gnome.system.proxy mode 'none'
  # Linux KDE
  elif command -v kwriteconfig5 >/dev/null 2>&1; then
    echo ""
    echo "${YELLOW}正在关闭 KDE 系统代理...${PLAIN}"
    kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType 0
  fi
}

install_xray_client() {
  echo "${GREEN}正在检测系统架构...${PLAIN}"
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  if [ "$OS" = "darwin" ]; then OS="macos"; fi
  ARCH=$(uname -m)

  case "$ARCH" in
    x86_64) ARCH="64" ;;
    aarch64|arm64) ARCH="arm64-v8a" ;;
    mips*) ARCH="mips32" ;; 
    *) echo "${RED}不支持的架构: $ARCH${PLAIN}"; return 1 ;;
  esac

  if [ "$IS_OPENWRT" -eq 1 ]; then
    echo "${GREEN}OpenWrt 环境: 尝试使用 opkg 安装...${PLAIN}"
    opkg update
    if opkg install xray-core; then return 0; fi
  fi

  DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-${OS}-${ARCH}.zip"
  ZIP_FILE="$SCRIPT_DIR/xray.zip"
  
  echo "${GREEN}正在下载 Xray-core (${OS}-${ARCH})...${PLAIN}"
  if command -v curl >/dev/null 2>&1; then curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"
  elif command -v wget >/dev/null 2>&1; then wget -O "$ZIP_FILE" "$DOWNLOAD_URL"
  fi

  if [ -f "$ZIP_FILE" ]; then
    unzip -o "$ZIP_FILE" -d "$SCRIPT_DIR"
    chmod +x "$SCRIPT_DIR/xray"
    rm "$ZIP_FILE"
    
    # 检查资源文件
    if [ ! -f "$SCRIPT_DIR/geoip.dat" ] || [ ! -f "$SCRIPT_DIR/geosite.dat" ]; then
      echo "${YELLOW}资源文件缺失，正在单独下载 geoip.dat 和 geosite.dat...${PLAIN}"
      curl -L -o "$SCRIPT_DIR/geoip.dat" "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat"
      curl -L -o "$SCRIPT_DIR/geosite.dat" "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
      # dlc.dat 重命名为 geosite.dat (v2fly 标准)
      mv "$SCRIPT_DIR/dlc.dat" "$SCRIPT_DIR/geosite.dat" 2>/dev/null
    fi
    
    echo "${GREEN}安装成功！${PLAIN}"
  else
    echo "${RED}下载失败。${PLAIN}"
    return 1
  fi
}

generate_xray_config() {
  LINK="$1"
  TEMP="${LINK#*://}"
  UUID="${TEMP%%@*}"
  TEMP="${TEMP#*@}"
  ADDRESS="${TEMP%%\?*}"
  IP="${ADDRESS%%:*}"
  PORT="${ADDRESS#*:}"
  QUERY="${TEMP#*\?}"
  QUERY="${QUERY%%\#*}"

  get_param() { echo "$QUERY" | awk -F"[=&]" '{for(i=1;i<=NF;i++){if($i=="'"$1"'") print $(i+1)}}'; }

  SNI=$(get_param "sni")
  PBK=$(get_param "pbk")
  SID=$(get_param "sid")
  FP=$(get_param "fp")
  TYPE=$(get_param "type")
  FLOW=$(get_param "flow")

  cat > "$SCRIPT_DIR/config.json" <<EOF
{
  "log": { "loglevel": "info", "access": "/dev/stdout", "error": "/dev/stderr" },
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      { "type": "field", "ip": ["geoip:private", "geoip:cn"], "outboundTag": "direct" },
      { "type": "field", "domain": ["geosite:cn"], "outboundTag": "direct" }
    ]
  },
  "inbounds": [
    {
      "port": $LOCAL_PORT,
      "listen": "$BIND_ADDR",
      "protocol": "socks",
      "settings": { "udp": true }
    }
EOF

  # OpenWrt TProxy 入站
  if [ "$IS_OPENWRT" -eq 1 ]; then
    cat >> "$SCRIPT_DIR/config.json" <<EOF
    ,
    {
      "port": 12345,
      "protocol": "dokodemo-door",
      "settings": { "network": "tcp,udp", "followRedirect": true },
      "streamSettings": { "sockopt": { "tproxy": "tproxy" } },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    }
EOF
  fi

  cat >> "$SCRIPT_DIR/config.json" <<EOF
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [{
          "address": "$IP", "port": $PORT,
          "users": [{"id": "$UUID", "flow": "$FLOW", "encryption": "none"}]
        }]
      },
      "streamSettings": {
        "network": "$TYPE", "security": "reality",
        "realitySettings": {
          "serverName": "$SNI", "publicKey": "$PBK", "fingerprint": "$FP", "shortId": "$SID"
        }
      }
    },
    { "tag": "direct", "protocol": "freedom", "settings": {} }
  ]
}
EOF
}

setup_tproxy() {
  if [ "$IS_OPENWRT" -ne 1 ]; then return; fi
  
  echo "${GREEN}正在配置 OpenWrt 透明代理 (TProxy)...${PLAIN}"
  
  # 安装依赖 (TProxy 模块)
  if ! opkg list-installed | grep -q kmod-ipt-tproxy; then
    echo "安装 TProxy 依赖..."
    opkg update
    opkg install iptables-mod-tproxy kmod-ipt-tproxy ip-full
  fi

  # 策略路由
  if ! ip rule show | grep -q "fwmark 0x1 lookup 100"; then
    ip rule add fwmark 1 table 100
  fi
  if ! ip route show table 100 | grep -q "local default dev lo"; then
    ip route add local 0.0.0.0/0 dev lo table 100
  fi

  # iptables 规则 (避免重复添加)
  iptables -t mangle -F XRAY 2>/dev/null
  iptables -t mangle -X XRAY 2>/dev/null
  iptables -t mangle -N XRAY
  
  # 直连局域网和私有地址
  iptables -t mangle -A XRAY -d 0.0.0.0/8 -j RETURN
  iptables -t mangle -A XRAY -d 10.0.0.0/8 -j RETURN
  iptables -t mangle -A XRAY -d 127.0.0.0/8 -j RETURN
  iptables -t mangle -A XRAY -d 169.254.0.0/16 -j RETURN
  iptables -t mangle -A XRAY -d 172.16.0.0/12 -j RETURN
  iptables -t mangle -A XRAY -d 192.168.0.0/16 -j RETURN
  iptables -t mangle -A XRAY -d 224.0.0.0/4 -j RETURN
  iptables -t mangle -A XRAY -d 240.0.0.0/4 -j RETURN
  
  # 劫持流量到 12345
  iptables -t mangle -A XRAY -p tcp -j TPROXY --on-port 12345 --tproxy-mark 1
  iptables -t mangle -A XRAY -p udp -j TPROXY --on-port 12345 --tproxy-mark 1
  
  # 应用到 PREROUTING 链
  if ! iptables -t mangle -C PREROUTING -j XRAY 2>/dev/null; then
    iptables -t mangle -A PREROUTING -j XRAY
  fi
  
  echo "${GREEN}透明代理已启动！所有连接 WiFi 的设备均可自动翻墙。${PLAIN}"
}

cleanup_tproxy() {
  if [ "$IS_OPENWRT" -ne 1 ]; then return; fi
  
  echo ""
  echo "${YELLOW}正在清理透明代理规则...${PLAIN}"
  iptables -t mangle -D PREROUTING -j XRAY 2>/dev/null
  iptables -t mangle -F XRAY 2>/dev/null
  iptables -t mangle -X XRAY 2>/dev/null
  ip rule del fwmark 1 table 100 2>/dev/null
  ip route del local 0.0.0.0/0 dev lo table 100 2>/dev/null
  echo "${GREEN}规则已清理。${PLAIN}"
}

stop_service() {
  echo "${YELLOW}正在停止服务...${PLAIN}"
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID"
      echo "已停止 Xray 进程 (PID: $PID)"
    fi
    rm "$PID_FILE"
  else
    pkill -f "xray run -c" 2>/dev/null
  fi
  
  unset_system_proxy
  cleanup_tproxy
  echo "${GREEN}服务已完全停止，网络已恢复。${PLAIN}"
}

start_vless_client() {
  [ -f "$SCRIPT_DIR/xray" ] || install_xray_client || return 1
  XRAY_BIN="$SCRIPT_DIR/xray"

  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      echo "${RED}检测到 Xray 已在运行 (PID: $PID)。请先停止服务。${PLAIN}"
      return 1
    else
      rm "$PID_FILE"
    fi
  fi

  touch "$NODES_FILE"
  echo "${BLUE}--- 节点管理 ---${PLAIN}"
  
  i=1
  while read -r line; do
    [ -z "$line" ] && continue
    name=$(echo "$line" | cut -d'|' -f1)
    link=$(echo "$line" | cut -d'|' -f2)
    eval "node_$i=\"$link\""
    eval "name_$i=\"$name\""
    echo "$i. $name"
    i=$((i+1))
  done < "$NODES_FILE"

  echo "$i. [新增节点]"
  printf "请选择 [1-%d]: " "$i"
  read -r node_choice

  if [ "$node_choice" -eq "$i" ]; then
    printf "请输入新节点备注名称: "
    read -r new_name
    printf "请输入 vless:// 链接: "
    read -r new_link
    echo "$new_name|$new_link" >> "$NODES_FILE"
    SELECTED_LINK="$new_link"
  else
    eval "SELECTED_LINK=\$node_$node_choice"
  fi

  if [ -z "$SELECTED_LINK" ]; then echo "${RED}无效选择${PLAIN}"; return 1; fi

  generate_xray_config "$SELECTED_LINK"
  
  printf "是否在后台运行 (推荐 OpenWrt 使用)? [y/N] "
  read -r bg_choice

  set_system_proxy
  setup_tproxy
  
  if [ "$bg_choice" = "y" ] || [ "$bg_choice" = "Y" ]; then
    echo "${GREEN}正在后台启动 Xray...${PLAIN}"
    nohup "$XRAY_BIN" run -c "$SCRIPT_DIR/config.json" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "${GREEN}服务已在后台运行 (PID: $(cat "$PID_FILE"))。${PLAIN}"
    echo "日志文件: $LOG_FILE"
    echo "您可以关闭终端了。如需停止，请重新运行脚本并选择 '4'。"
  else
    trap 'unset_system_proxy; cleanup_tproxy' EXIT INT TERM

    if [ "$IS_OPENWRT" -eq 1 ]; then
      echo "${GREEN}VLESS 透明代理已启动 (全屋翻墙模式)...${PLAIN}"
    else
      echo "${GREEN}VLESS 代理已启动 (系统代理模式)...${PLAIN}"
    fi
    
    "$XRAY_BIN" run -c "$SCRIPT_DIR/config.json"
  fi
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
echo "3. ${YELLOW}启动 VLESS-Reality 模式${PLAIN} (自动下载 Xray)"
echo "4. ${RED}停止服务 & 清理规则${PLAIN}"
echo "0. 退出"
echo "==================================================="

printf "请输入选项 [0-4]: "
read -r choice

case "$choice" in
1)
  start_ssh_tunnel
  ;;
2)
  start_ss_client
  ;;
3)
  start_vless_client
  ;;
4)
  stop_service
  ;;
0)
  exit 0
  ;;
*)
  echo "${RED}无效选项，默认启动 SSH 隧道...${PLAIN}"
  start_ssh_tunnel
  ;;
esac
