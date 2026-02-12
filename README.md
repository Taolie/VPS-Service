# 全平台 VPS 代理服务

这是一个基于 Shadowsocks (SOCKS5) 和 SSH 隧道的全平台代理解决方案。
它可以帮助你在任何设备上（电脑、手机、路由器）安全地访问互联网，且无需域名。

## 项目架构

```
VPS-Service/
├── Server-Side/           # 服务端自动部署脚本
│   └── install_ss.sh      # 一键安装 Shadowsocks 服务端
│
├── Client-Side/           # 客户端连接工具 & 文档
│   ├── macOS_Linux/       # macOS 和 Linux 专用 (SSH 隧道 & PAC)
│   ├── Windows/           # Windows 专用 (PowerShell 脚本)
│   ├── Router/            # OpenWrt 路由器专用脚本
│   └── Mobile_Guide.md    # iOS / Android 手机配置指南
```

## 第一步：服务端部署 (VPS)

你需要一台 Linux VPS (CentOS/Ubuntu/Debian)。

1.  **上传脚本**: 将 `Server-Side/install_ss.sh` 上传到你的 VPS。
2.  **运行安装**:
    ```bash
    chmod +x install_ss.sh
    ./install_ss.sh
    ```
3.  **获取信息**:
    安装完成后，脚本会输出以下重要信息，请务必保存：
    *   服务器 IP
    *   端口 (Port)
    *   密码 (Password)
    *   加密方式 (Method)
    *   ss:// 链接

---

## 第二步：客户端配置 (Client)

根据你的设备选择对应的配置方法：

### 1. 手机 (iOS / Android)
请直接阅读文档: `Client-Side/Mobile_Guide.md`。
*   **iOS**: 使用 Shadowrocket / Quantumult X / Loon。
*   **Android**: 使用 Shadowsocks / v2rayNG。
*   **方法**: 填入第一步获取的 IP、端口、密码和加密方式即可。

### 2. macOS / Linux
你可以选择两种方式：
*   **方案 A (推荐): 使用 GUI 客户端**
    *   下载 `ShadowsocksX-NG` (macOS) 或 `Shadowsocks-Qt5` (Linux)。
    *   导入 `ss://` 链接。
*   **方案 B (原生): 使用 SSH 隧道 (无需服务端支持)**
    *   进入 `Client-Side/macOS_Linux/` 目录。
    *   修改 `vps_tunnel.sh` 填入 VPS IP。
    *   运行 `./vps_tunnel.sh start` 或双击 `Start.command`。

### 3. Windows
*   **方案 A (推荐): 使用 GUI 客户端**
    *   下载 `Shadowsocks-Windows`。
    *   导入 `ss://` 链接。
*   **方案 B (原生): 使用 PowerShell 脚本**
    *   进入 `Client-Side/Windows/` 目录。
    *   右键 `Start-SSHTunnel.ps1` -> 使用 PowerShell 运行。

### 4. 路由器 (OpenWrt)
*   进入 `Client-Side/Router/` 目录。
*   修改 `router_ss.sh` 中的服务器信息。
*   上传到路由器并运行，启动 SOCKS5 代理。

---

## 常见问题

1.  **为什么没有使用 Trojan?**
    *   因为 Trojan 需要域名和 SSL 证书。本项目采用了更通用的 Shadowsocks 方案，无需域名即可使用。
    
2.  **连接不上怎么办?**
    *   请首先检查 VPS 的防火墙 (Firewall/Security Group) 是否放行了 TCP 和 UDP 端口。
    *   检查密码和加密方式是否填写正确 (Shadowsocks 对此非常敏感)。
