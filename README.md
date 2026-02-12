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

### 2. macOS / Linux / OpenWrt (路由器)
*   **推荐方式**: 使用统一启动脚本。
*   **操作**: 
    1. 进入 `Client-Side/` 目录。
    2. 运行 `./connect.sh`。
    3. 根据菜单选择模式。
    *   **特别说明**: 如果脚本检测到在 **OpenWrt** 上运行，会自动将监听地址改为 `0.0.0.0`，方便局域网内其他设备连接。

### 3. Windows
*   **推荐方式**: 使用统一启动脚本。
*   **操作**:
    1. 进入 `Client-Side/` 目录。
    2. 右键 `connect.ps1` -> **使用 PowerShell 运行**。
    3. 支持 SSH 隧道和 Shadowsocks 模式。

---

## 常见问题

1.  **为什么没有使用 Trojan?**
    *   因为 Trojan 需要域名和 SSL 证书。本项目采用了更通用的 Shadowsocks 方案，无需域名即可使用。
    
2.  **连接不上怎么办?**
    *   **90% 的原因是防火墙没开。** 服务器有两道门，都需要打开：
        ```
        Internet (你)
           ↓
        [云厂商安全组]  <-- 必须去网页控制台手动放行 (TCP+UDP 端口)
           ↓
        [VPS 系统防火墙] <-- 脚本已为您自动打开 (ufw/firewalld)
           ↓
        [SS 服务]
        ```
    *   请登录阿里云/腾讯云/AWS 控制台，找到“安全组”或“防火墙”设置，添加一条入站规则，允许脚本生成的端口 (TCP+UDP)。
    *   检查密码和加密方式是否填写正确 (Shadowsocks 对此非常敏感)。
