# VPS 客户端统一连接工具 (Windows PowerShell)
# ==============================================================================
# [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
# [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
# [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "")]
# [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]

# 设置控制台编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 获取脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ConfigFile = Join-Path $ProjectRoot "config.ini"

# 检查配置文件
if (-not (Test-Path $ConfigFile)) {
    Write-Output "错误: 找不到配置文件 $ConfigFile"
    Write-Output "请先复制 config.ini.example 为 config.ini 并填写配置。"
    exit
}

# 读取配置文件 (简单的 INI 解析)
Get-Content $ConfigFile | Where-Object { $_ -notmatch "^#" -and $_ -ne "" } | ForEach-Object {
    $parts = $_ -split "=", 2
    if ($parts.Count -eq 2) {
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        # 动态创建变量
        New-Variable -Name $key -Value $value -Force -Scope Script
    }
}

# 检查配置是否填写
if ($script:VPS_HOST -eq "YOUR_VPS_IP") {
    Write-Output "错误: 请先编辑 config.ini 填入 VPS IP 地址！"
    exit
}

# ==============================================================================
# 功能函数
# ==============================================================================

function Start-SSHTunnel {
    param()
    
    Write-Output "正在启动 SSH 隧道..."
    Write-Output "目标服务器: $script:VPS_USER@$script:VPS_HOST"
    Write-Output "本地端口: $script:LOCAL_PORT"
    Write-Output "请在提示时输入 VPS 登录密码。"
    
    ssh -C -N -D 127.0.0.1:$script:LOCAL_PORT "$script:VPS_USER@$script:VPS_HOST"
}

function Start-SSClient {
    param()

    # 检查 ss-local 是否存在
    $SSPath = Join-Path $ScriptDir "ss-local.exe"
    
    if (-not (Test-Path $SSPath)) {
        Write-Output "未检测到 Shadowsocks 客户端 (ss-local.exe)。"
        $Download = Read-Host "是否尝试自动下载 (从 GitHub)? [y/N]"
        
        if ($Download -match "^[yY]") {
            Write-Output "正在下载 ss-local (Windows版)..."
            Write-Output "由于网络原因，无法自动下载。请手动下载 Shadowsocks-libev for Windows。"
            Write-Output "下载地址: https://github.com/shadowsocks/shadowsocks-libev/releases"
            Write-Output "解压后将 ss-local.exe 放入此脚本同级目录即可。"
            Start-Sleep -Seconds 5
            return
        } else {
            return
        }
    }

    Write-Output "正在启动 Shadowsocks 客户端..."
    Write-Output "服务器: $script:VPS_HOST:$script:SS_PORT"
    
    & "$SSPath" -s "$script:VPS_HOST" -p "$script:SS_PORT" -k "$script:SS_PASSWORD" -m "$script:SS_METHOD" -l "$script:LOCAL_PORT" -b "127.0.0.1" -v
}

function Start-V2RayN {
    param()
    
    $V2RayNDir = Join-Path $ScriptDir "v2rayN-Core"
    $V2RayNExe = Join-Path $V2RayNDir "v2rayN.exe"
    $ZipPath = Join-Path $ScriptDir "v2rayN-Core.zip"
    # 使用 v2rayN 6.23 正式版 (稳定且包含 Core)
    $DownloadUrl = "https://github.com/2dust/v2rayN/releases/download/6.23/v2rayN-Core.zip"

    # 1. 检查并下载 v2rayN
    if (-not (Test-Path $V2RayNExe)) {
        Write-Output "未检测到 v2rayN 客户端。"
        $Download = Read-Host "是否自动下载 v2rayN-Core (约 50MB)? [Y/n]"
        
        if ($Download -match "^[nN]") {
            Write-Output "已取消。请手动下载 v2rayN-Core.zip 解压到 Client-Side/v2rayN-Core 目录。"
            return
        }

        Write-Output "正在下载 v2rayN-Core.zip (来自 GitHub)..."
        try {
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
        } catch {
            Write-Output "下载失败: $_"
            Write-Output "请检查网络或手动下载: $DownloadUrl"
            return
        }

        Write-Output "正在解压..."
        Expand-Archive -Path $ZipPath -DestinationPath $V2RayNDir -Force
        Remove-Item $ZipPath -Force
        Write-Output "安装完成！"
    }

    # 2. 获取 VLESS 链接
    $VlessLink = ""
    # 尝试从 config.ini 读取 (如果存在)
    if ($script:VLESS_URI) {
        $VlessLink = $script:VLESS_URI
    } else {
        Write-Output "`n请输入您的 VLESS 链接 (vless://...):"
        Write-Output "(您可以将其添加到 config.ini 的 VLESS_URI=... 以便自动读取)"
        $VlessLink = Read-Host "链接"
    }

    if ([string]::IsNullOrWhiteSpace($VlessLink)) {
        Write-Output "错误: 链接不能为空。"
        return
    }

    # 3. 复制到剪贴板并启动
    try {
        Set-Clipboard -Value $VlessLink
        Write-Output "✅ VLESS 链接已复制到剪贴板！"
    } catch {
        Write-Output "⚠️ 无法访问剪贴板，请手动复制链接。"
    }

    Write-Output "正在启动 v2rayN..."
    Start-Process -FilePath $V2RayNExe

    Write-Output "`n==================================================="
    Write-Output "🚀 v2rayN 已启动！请按以下步骤操作："
    Write-Output "1. 在 v2rayN 界面中，按下 [Ctrl + V] 导入服务器。"
    Write-Output "2. 选中导入的服务器，按 [Enter] 设为活动服务器。"
    Write-Output "3. 在底部系统托盘图标右键 -> 自动配置系统代理。"
    Write-Output "==================================================="
}

# ==============================================================================
# 主菜单
# ==============================================================================

Clear-Host
Write-Output "==================================================="
Write-Output "VPS 客户端统一连接工具 (Windows)"
Write-Output "==================================================="
Write-Output "当前配置:"
Write-Output "  VPS IP: $script:VPS_HOST"
Write-Output "  本地端口: $script:LOCAL_PORT"
Write-Output "==================================================="
Write-Output "1. 启动 SSH 隧道模式 (推荐，无需安装)"
Write-Output "2. 启动 Shadowsocks 模式 (需下载 ss-local.exe)"
Write-Output "3. 启动 VLESS-Reality 模式 (自动下载 v2rayN)"
Write-Output "0. 退出"
Write-Output "==================================================="

$Choice = Read-Host "请输入选项 [1-3]"

switch ($Choice) {
    "1" { Start-SSHTunnel }
    "2" { Start-SSClient }
    "3" { Start-V2RayN }
    
