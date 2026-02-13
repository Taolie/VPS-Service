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
3. **结果**: 脚本输出 `vless://` 开头的分享链接。**无需域名，直接使用 IP 连接。**

---

## 第二步：客户端配置 (Client)

### 如果你选择了 [方案 A: Shadowsocks]

* **macOS / Linux / OpenWrt**: 运行 `Client-Side/connect.sh`，选择 Shadowsocks 模式。
* **Windows**: 右键运行 `Client-Side/connect.ps1`。
* **手机**: 参考 `Client-Side/Mobile_Guide.md`。

### 如果你选择了 [方案 B: VLESS + Reality]

此模式需要使用支持 Xray 内核的专用客户端。无法使用简单的 Shell 脚本连接。

#### 1. Windows
* **推荐软件**: [v2rayN](https://github.com/2dust/v2rayN/releases)
* **配置**: 复制服务端生成的 `vless://...` 链接 -> 打开 v2rayN -> `Ctrl+V` (从剪贴板导入) -> 设为活动服务器。

#### 2. macOS
* **推荐软件**: [V2RayXS](https://github.com/bnd1/V2RayXS) 或 [FoXray](https://github.com/ItzLevvie/FoXray)
* **配置**: 复制 `vless://...` 链接 -> 导入到软件中 -> 启动。

#### 3. Android
* **推荐软件**: [v2rayNG](https://github.com/2dust/v2rayNG/releases)
* **配置**: 复制 `vless://...` 链接 -> 打开 App -> 点击右上角 `+` -> 从剪贴板导入。

#### 4. iOS
* **推荐软件**: Shadowrocket (需非国区 Apple ID 购买) 或 Stash。
* **配置**: 复制 `vless://...` 链接 -> 打开 App -> 自动识别并添加。

---

## 常见问题

1. **Reality 为什么不需要域名？**
   * Reality 协议通过“偷取”目标网站（如 Microsoft）的 TLS 握手特征，让你的流量看起来像是在访问 Microsoft。因此它不需要你自己购买域名和证书，直接用 IP 即可，且隐蔽性极高。

2. **连接不上怎么办?**
   * **90% 的原因是防火墙没开。** 务必去云厂商控制台（阿里云/腾讯云/AWS等）的**安全组**设置中，放行脚本输出的端口（TCP）。
   * **检查时间**: VLESS 协议对时间非常敏感，请确保客户端和服务器的时间误差在 90秒以内。

3. **为什么 connect.sh 不能直接连 VLESS?**
   * VLESS-Reality 需要 Xray 完整核心，体积较大且配置复杂，不适合集成在轻量级的 Shell 脚本中。使用 GUI 客户端体验更好。
