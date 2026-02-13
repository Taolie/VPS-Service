# 变更日志 (Changelog)

本项目的所有显著更改都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵守 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- **VLESS 客户端支持**: `connect.sh` 现在集成了 VLESS-Reality 模式，支持自动下载 Xray 核心、解析链接并启动代理。
- **自定义端口**: `install_vless.sh` 增加交互式端口设置，支持避开 443 端口冲突。

### Changed
- **UI 颜色增强**: `connect.sh` 颜色定义改用 `tput`，显著提升 macOS 终端兼容性。
- **统一连接入口**: 为 macOS/Linux 和 Windows 创建了 `connect.sh` 和 `connect.ps1`。
- **智能依赖安装**: `connect.sh` 现在可以自动检测并使用包管理器安装 `shadowsocks-libev`。
- **配置同步**: 客户端脚本现在自动读取根目录的 `config.ini`，无需重复填写。
- 初始化 Git 仓库。
- 添加 `config.ini.example` 配置模板。
- 添加 `TODO.md` 任务列表。
- 将 `GEMINI.md` 迁移至标准的 `README.md`。

### Changed
- **目录重构**: 清理了 `Client-Side` 下零散的平台文件夹，统一存放于根目录。
- **OpenWrt 支持**: `connect.sh` 现在兼容 OpenWrt 环境，自动识别并配置局域网共享，移除了独立的 `Router` 目录。
## [0.1.0] - 2023-10-27
### Added
- 初始版本发布。
- 服务端: `install_ss.sh` 一键安装脚本。
- 客户端: macOS/Linux/Windows 连接脚本。
- 文档: 基础使用指南。
