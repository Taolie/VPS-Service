# 移动端配置指南 (iOS & Android)

本指南将帮助你在手机上配置 Shadowsocks 客户端，连接到你的 VPS 代理服务。

## 准备工作

在开始之前，请确保你已经运行了 `Server-Side/install_ss.sh` 脚本，并获得了以下信息：
*   **服务器 IP (Server IP)**
*   **服务器端口 (Port)**: 例如 `8388`
*   **密码 (Password)**: 例如 `MyStrongPassword`
*   **加密方式 (Method)**: 例如 `chacha20-ietf-poly1305`

---

## iOS (iPhone / iPad)

由于 App Store 中国区政策限制，你需要使用**非中国区 Apple ID** (如美区、港区) 才能下载以下应用。

### 推荐应用
1.  **Shadowrocket** (俗称“小火箭”，推荐，收费约 $2.99)
2.  **Quantumult X** (功能强大，收费)
3.  **Loon** (轻量级，收费)

### 配置步骤 (以 Shadowrocket 为例)
1.  打开 Shadowrocket。
2.  点击右上角的 `+` 号。
3.  **类型 (Type)**: 选择 `Shadowsocks`。
4.  **地址 (Address)**: 填入你的 **服务器 IP**。
5.  **端口 (Port)**: 填入你的 **服务器端口**。
6.  **密码 (Password)**: 填入你的 **密码**。
7.  **算法 (Algorithm)**: 选择对应的 **加密方式** (如 `chacha20-ietf-poly1305`)。
8.  点击右上角的 `完成`。
9.  在首页开启连接开关，允许添加 VPN 配置。
10. **模式选择**: 建议选择 `配置 (Config)` 模式，这样国内网站直连，国外网站走代理。

---

## Android (安卓)

安卓系统比较开放，你可以直接下载 APK 安装包。

### 推荐应用
1.  **Shadowsocks (官方版)**: 最简单直接。
    *   [GitHub 下载地址](https://github.com/shadowsocks/shadowsocks-android/releases)
2.  **v2rayNG**: 支持多种协议，功能更全。
    *   [GitHub 下载地址](https://github.com/2dust/v2rayNG/releases)

### 配置步骤 (以 Shadowsocks 官方版为例)
1.  打开 App。
2.  点击右上角的 `+` 号 -> `手动设置`。
3.  **服务器**: 填入 **服务器 IP**。
4.  **远程端口**: 填入 **服务器端口**。
5.  **密码**: 填入 **密码**。
6.  **加密方法**: 选择对应的 **加密方式**。
7.  点击右上角的 `√` 保存。
8.  选中刚才添加的配置，点击底部的 `圆形飞机图标` 连接。
9.  第一次连接会弹出“网络连接请求”，点击 `确定`。

---

## 常见问题

*   **Q: 连接成功但无法上网？**
    *   A: 请检查 VPS 服务商的防火墙（安全组）是否放行了你在脚本中设置的端口 (TCP 和 UDP)。
    *   A: 检查加密方式是否选择正确，Shadowsocks 对加密方式非常敏感，选错一个字符都无法连接。

*   **Q: 速度慢？**
    *   A: 这取决于你的 VPS 线路质量（CN2 GIA 线路最佳）。如果晚上拥堵，尝试开启 BBR 加速（我们的脚本后续会集成）。
