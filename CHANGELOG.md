# 变更日志 (Changelog)

本项目的所有显著更改都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵守 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- **统一连接入口**: 为 macOS/Linux 和 Windows 创建了 `connect.sh` 和 `connect.ps1`。
- **智能依赖安装**: `connect.sh` 现在可以自动检测并使用包管理器安装 `shadowsocks-libev`。
- **配置同步**: 客户端脚本现在自动读取根目录的 `config.ini`，无需重复填写。
- 初始化 Git 仓库。
- 添加 `config.ini.example` 配置模板。
- 添加 `TODO.md` 任务列表。
- 将 `GEMINI.md` 迁移至标准的 `README.md`。

### Changed
- **目录重构**: 清理了 `Client-Side` 下零散的平台文件夹，统一存放于根目录。
## [0.1.0] - 2023-10-27
### Added
- 初始版本发布。
- 服务端: `install_ss.sh` 一键安装脚本。
- 客户端: macOS/Linux/Windows 连接脚本。
- 文档: 基础使用指南。
