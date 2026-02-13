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
  
  # 如果变量为空或为默认值，则提示输入
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

  if ! ensure_config "VPS_HOST" "请输入 VPS IP 地址:"; then return; fi
  if ! ensure_config "SS_PORT" "请输入 Shadowsocks 端口:"; then return; fi
  if ! ensure_config "SS_PASSWORD" "请输入 Shadowsocks 密码:"; then return; fi
  if ! ensure_config "SS_METHOD" "请输入加密方式 (默认 chacha20-ietf-poly1305):"; then return; fi

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

# ------------------------------------------------------------------------------
# VLESS-Reality 客户端逻辑
# ------------------------------------------------------------------------------

install_xray_client() {
  echo "${GREEN}正在检测系统架构...${PLAIN}"
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)

  case "$ARCH" in
    x86_64) ARCH="64" ;;
    aarch64|arm64) ARCH="arm64-v8a" ;;
    mips*) ARCH="mips32" ;; 
    *) echo "${RED}不支持的架构: $ARCH${PLAIN}"; return 1 ;;
  esac

  # OpenWrt 优先尝试 opkg
  if [ "$IS_OPENWRT" -eq 1 ]; then
    echo "${GREEN}OpenWrt 环境: 尝试使用 opkg 安装...${PLAIN}"
    opkg update
    if opkg install xray-core; then
      return 0
    fi
    echo "${YELLOW}opkg 安装失败，尝试下载二进制...${PLAIN}"
  fi

  DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-${OS}-${ARCH}.zip"
  ZIP_FILE="$SCRIPT_DIR/xray.zip"
  
  echo "${GREEN}正在下载 Xray-core (${OS}-${ARCH})...${PLAIN}"
  # 检查 curl 或 wget
  if command -v curl >/dev/null 2>&1; then
    curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$ZIP_FILE" "$DOWNLOAD_URL"
  else
    echo "${RED}错误: 未找到 curl 或 wget，无法下载。${PLAIN}"
    return 1
  fi

  if [ -f "$ZIP_FILE" ]; then
    # 检查 unzip
    if ! command -v unzip >/dev/null 2>&1; then
      echo "${RED}错误: 未找到 unzip 命令。${PLAIN}"
      if [ "$IS_OPENWRT" -eq 1 ]; then echo "请运行: opkg install unzip"; fi
      return 1
    fi

    unzip -o "$ZIP_FILE" -d "$SCRIPT_DIR" xray
    chmod +x "$SCRIPT_DIR/xray"
    rm "$ZIP_FILE"
    echo "${GREEN}安装成功！${PLAIN}"
  else
    echo "${RED}下载失败。${PLAIN}"
    return 1
  fi
}

generate_xray_config() {
  LINK="$1"
  # 简单的 Shell 解析 (提取关键参数)
  # 格式: vless://UUID@IP:PORT?params#NAME
  
  # 去除 vless:// 前缀
  TEMP="${LINK#*://}"
  # 提取 UUID (截取到第一个 @)
  UUID="${TEMP%%@*}"
  TEMP="${TEMP#*@}"
  # 提取 IP:PORT (截取到第一个 ?)
  ADDRESS="${TEMP%%\?*}"
  IP="${ADDRESS%%:*}"
  PORT="${ADDRESS#*:}"
  # 提取参数部分 (截取第一个 ? 之后)
  QUERY="${TEMP#*\?}"
  # 去除可能存在的 #备注
  QUERY="${QUERY%%\#*}"

  # 提取参数值辅助函数 (grep -o + cut)
  # 注意: OpenWrt 默认 grep 可能不支持 -o，这里使用 awk
  get_param() {
    echo "$QUERY" | awk -F"[=&]" '{for(i=1;i<=NF;i++){if($i=="'"$1"'") print $(i+1)}}'
  }

  SNI=$(get_param "sni")
  PBK=$(get_param "pbk")
  SID=$(get_param "sid")
  FP=$(get_param "fp")
  TYPE=$(get_param "type")
  FLOW=$(get_param "flow")

  # 生成 config.json
  cat > "$SCRIPT_DIR/config.json" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $LOCAL_PORT,
      "listen": "$BIND_ADDR",
      "protocol": "socks",
      "settings": { "udp": true }
    }
  ],
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$IP",
            "port": $PORT,
            "users": [
              {
                "id": "$UUID",
                "flow": "$FLOW",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "$TYPE",
        "security": "reality",
        "realitySettings": {
          "serverName": "$SNI",
          "publicKey": "$PBK",
          "fingerprint": "$FP",
          "shortId": "$SID",
          "spiderX": ""
        }
      }
    }
  ]
}
EOF
}

start_vless_client() {
  # 1. 确定 Xray 路径
  XRAY_BIN="./xray"
  if [ -f "$SCRIPT_DIR/xray" ]; then
    XRAY_BIN="$SCRIPT_DIR/xray"
  elif command -v xray >/dev/null 2>&1; then
    XRAY_BIN="xray"
  else
    echo "${YELLOW}未检测到 Xray 核心。${PLAIN}"
    printf "是否自动下载安装? [y/N] "
    read -r install_choice
    case "$install_choice" in
      [yY]*)
        install_xray_client
        if [ -f "$SCRIPT_DIR/xray" ]; then
          XRAY_BIN="$SCRIPT_DIR/xray"
        else
          return 1
        fi
        ;;
      *)
        echo "${YELLOW}已取消。${PLAIN}"
        return 1
        ;;
    esac
  fi

  # 2. 获取链接
  VLESS_LINK="$VLESS_URI"
  if [ -z "$VLESS_LINK" ]; then
    echo "${YELLOW}请输入 VLESS 链接 (vless://...):${PLAIN}"
    echo "(提示: 您可以将链接填入 config.ini 的 VLESS_URI 字段以自动读取)"
    read -r VLESS_LINK
  fi

  if [ -z "$VLESS_LINK" ]; then
    echo "${RED}错误: 链接不能为空。${PLAIN}"
    return 1
  fi

  # 3. 生成配置
  echo "${GREEN}正在生成配置文件...${PLAIN}"
  generate_xray_config "$VLESS_LINK"

  # 4. 启动
  echo "${GREEN}正在启动 Xray 客户端...${PLAIN}"
  echo "服务器: ${YELLOW}$IP:$PORT${PLAIN}"
  echo "本地监听: ${YELLOW}$BIND_ADDR:$LOCAL_PORT${PLAIN}"
  echo "正在运行... (按 Ctrl+C 停止)"
  
  "$XRAY_BIN" run -c "$SCRIPT_DIR/config.json"
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
echo "0. 退出"
echo "==================================================="

printf "请输入选项 [1-3]: "
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
0)
  exit 0
  ;;
*)
  echo "${RED}无效选项，默认启动 SSH 隧道...${PLAIN}"
  start_ssh_tunnel
  ;;
esac
