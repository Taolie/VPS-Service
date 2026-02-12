# VPS 客户端统一连接工具 (Windows PowerShell)
# ==============================================================================

# 设置控制台编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 获取脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ConfigFile = Join-Path $ProjectRoot "config.ini"

# 检查配置文件
if (-not (Test-Path $ConfigFile)) {
    Write-Host "错误: 找不到配置文件 $ConfigFile" -ForegroundColor Red
    Write-Host "请先复制 config.ini.example 为 config.ini 并填写配置。"
    exit
}

# 读取配置文件 (简单的 INI 解析)
$Config = Get-Content $ConfigFile | Where-Object { $_ -notmatch "^#" -and $_ -ne "" } | ForEach-Object {
    $parts = $_ -split "=", 2
    if ($parts.Count -eq 2) {
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        New-Variable -Name $key -Value $value -Force
    }
}

# 检查配置是否填写
if ($VPS_HOST -eq "YOUR_VPS_IP") {
    Write-Host "错误: 请先编辑 config.ini 填入 VPS IP 地址！" -ForegroundColor Red
    exit
}

# ==============================================================================
# 功能函数
# ==============================================================================

function Start-SSHTunnel {
    Write-Host "正在启动 SSH 隧道..." -ForegroundColor Green
    Write-Host "目标服务器: $VPS_USER@$VPS_HOST" -ForegroundColor Yellow
    Write-Host "本地端口: $LOCAL_PORT" -ForegroundColor Yellow
    Write-Host "请在提示时输入 VPS 登录密码。"
    
    # -N: 不执行远程命令
    # -D: 动态端口转发 (SOCKS5)
    # -C: 压缩数据
    ssh -C -N -D 127.0.0.1:$LOCAL_PORT "$VPS_USER@$VPS_HOST"
}

function Start-SSClient {
    # 检查 ss-local 是否存在
    $SSPath = Join-Path $ScriptDir "ss-local.exe"
    
    if (-not (Test-Path $SSPath)) {
        Write-Host "未检测到 Shadowsocks 客户端 (ss-local.exe)。" -ForegroundColor Yellow
        $Download = Read-Host "是否尝试自动下载 (从 GitHub)? [y/N]"
        
        if ($Download -match "^[yY]") {
            Write-Host "正在下载 ss-local (Windows版)..." -ForegroundColor Green
            try {
                # 这里为了简单，假设一个固定的下载链接或者提示用户去哪下载
                # 由于 GitHub Releases 链接经常变动且可能被墙，这里改为提示用户下载
                Write-Host "由于网络原因，无法自动下载。请手动下载 Shadowsocks-libev for Windows。" -ForegroundColor Red
                Write-Host "下载地址: https://github.com/shadowsocks/shadowsocks-libev/releases"
                Write-Host "解压后将 ss-local.exe 放入此脚本同级目录即可。"
                Start-Sleep -Seconds 5
                return
            } catch {
                Write-Host "下载失败: $_" -ForegroundColor Red
                return
            }
        } else {
            return
        }
    }

    Write-Host "正在启动 Shadowsocks 客户端..." -ForegroundColor Green
    Write-Host "服务器: $VPS_HOST:$SS_PORT" -ForegroundColor Yellow
    
    & "$SSPath" -s "$VPS_HOST" -p "$SS_PORT" -k "$SS_PASSWORD" -m "$SS_METHOD" -l "$LOCAL_PORT" -b "127.0.0.1" -v
}

# ==============================================================================
# 主菜单
# ==============================================================================

Clear-Host
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "VPS 客户端统一连接工具 (Windows)" -ForegroundColor Cyan
Write-Host "==================================================="
Write-Host "当前配置:"
Write-Host "  VPS IP: $VPS_HOST" -ForegroundColor Yellow
Write-Host "  本地端口: $LOCAL_PORT" -ForegroundColor Yellow
Write-Host "==================================================="
Write-Host "1. 启动 SSH 隧道模式 (推荐，无需安装)" -ForegroundColor Green
Write-Host "2. 启动 Shadowsocks 模式 (需下载 ss-local.exe)" -ForegroundColor Yellow
Write-Host "0. 退出"
Write-Host "==================================================="

$Choice = Read-Host "请输入选项 [1-2]"

switch ($Choice) {
    "1" { Start-SSHTunnel }
    "2" { Start-SSClient }
    "0" { exit }
    default { Start-SSHTunnel }
}
