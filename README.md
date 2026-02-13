# 全平台 VPS 代理服务

这是一个全平台代理解决方案，提供两种模式供选择：
1. **Shadowsocks**: 简单、兼容性好（旧版客户端可用）。
2. **VLESS + Reality**: **推荐**，极度隐蔽，无需域名，抗封锁能力强。

它可以帮助你在任何设备上（电脑、手机、路由器）安全地访问互联网。

## 项目架构

```text
VPS-Service/
├── Server-Side/
│   ├── install_ss.sh      # [选项A] 一键安装 Shadowsocks (简单)
│   └── install_vless.sh   # [选项B] 一键安装 VLESS+Reality (推荐)
│
├── Client-Side/           # 客户端连接工具 & 文档
│   ├── connect.sh         # macOS / Linux / OpenWrt 统一启动脚本
│   ├── connect.ps1        # Windows 统一启动脚本
│   └── Mobile_Guide.md    # iOS / Android 手机配置指南
```

## 第一步：服务端部署 (VPS)

你需要一台 Linux VPS (CentOS/Ubuntu/Debian)。选择以下一种方案即可。

### 方案 A：Shadowsocks (简单)

1. **上传**: 将 `Server-Side/install_ss.sh` 上传到 VPS。
2. **安装**:
   ```bash
   chmod +x install_ss.sh
   ./install_ss.sh
   ```
3. **结果**: 脚本输出 IP、端口、密码和 SS 链接。

### 方案 B：VLESS + Reality (推荐，更隐蔽)

1. **上传**: 将 `Server-Side/install_vless.sh` 上传到 VPS。
2. **安装**:
   ```bash
   chmod +x install_vless.sh
   ./install_vless.sh
   ```
3. **设置**: 脚本会提示你输入服务端口（默认 443）。
4. **结果**: 脚本输出 `vless://` 开头的分享链接。**无需域名，直接使用 IP 连接。**

---

## 第二步：客户端配置 (Client)

### 方案 A & B 统一配置

* **macOS / Linux / OpenWrt**: 运行 `Client-Side/connect.sh`。
  * 选择 **1** 启动 SSH 隧道。
  * 选择 **2** 启动 Shadowsocks。
  * 选择 **3** 启动 **VLESS-Reality** (脚本会自动为你配置 Xray 环境)。
* **Windows**: 右键运行 `Client-Side/connect.ps1`。
* **手机**: 参考 `Client-Side/Mobile_Guide.md`。

---

## 常见问题

1. **Reality 为什么不需要域名？**
   * Reality 协议通过“偷取”目标网站（如 Microsoft）的 TLS 握手特征，让你的流量看起来像是在访问 Microsoft。因此它不需要你自己购买域名和证书，直接用 IP 即可，且隐蔽性极高。

2. **连接不上怎么办?**
   * **90% 的原因是防火墙没开。** 务必去云厂商控制台（阿里云/腾讯云/AWS等）的**安全组**设置中，放行脚本输出的端口（TCP）。
   * **检查时间**: VLESS 协议对时间非常敏感，请确保客户端和服务器的时间误差在 90秒以内。
