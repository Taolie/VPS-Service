<#
.SYNOPSIS
    在 Windows 上启动 SSH SOCKS5 代理隧道。

.DESCRIPTION
    此脚本用于通过 OpenSSH 客户端连接到你的 VPS，并在本地开启 SOCKS5 代理。
    它不仅启动连接，还会自动设置 Windows 系统代理 (IE/Edge/Chrome/System)。

.NOTES
    你需要修改下面的 $VPS_User, $VPS_Host 和 $SSH_Key (可选)。
    你需要以管理员身份运行此脚本 (因为要设置系统代理)。
#>

# ==============================================================================
# 配置加载模块
# ==============================================================================
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptPath "..\..\config.ini"

if (-not (Test-Path $ConfigPath)) {
    Write-Error "找不到配置文件: $ConfigPath"
    Write-Warning "请确保 config.ini 位于项目根目录。"
    Read-Host "按回车键退出..."
    exit
}

# 读取配置
$ConfigContent = Get-Content $ConfigPath
$VPS_User = ($ConfigContent | Select-String "^VPS_USER=(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }).Trim()
$VPS_Host = ($ConfigContent | Select-String "^VPS_HOST=(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }).Trim()
$Local_Port = ($ConfigContent | Select-String "^LOCAL_PORT=(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }).Trim()

# 验证配置
if ([string]::IsNullOrWhiteSpace($VPS_Host) -or $VPS_Host -eq "YOUR_VPS_IP") {
    Write-Error "配置无效: 请先打开 VPS-Service/config.ini 并填入你的 VPS_HOST (IP地址)！"
    Read-Host "按回车键退出..."
    exit
}

Write-Host "已加载配置: VPS=$VPS_Host ($VPS_User), Port=$Local_Port" -ForegroundColor Cyan
# ==============================================================================

# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "请右键点击本脚本，选择 '以管理员身份运行' (Run as Administrator)。"
    Read-Host "按回车键退出..."
    exit
}

# 检查 SSH 命令是否存在
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Error "未找到 SSH 命令！请在 设置 -> 应用 -> 可选功能 中安装 OpenSSH Client。"
    Read-Host "按回车键退出..."
    exit
}

Write-Host "正在启动 SSH 隧道..." -ForegroundColor Cyan

# 构建 SSH 命令
$SSH_Command = "ssh -N -D $Local_Port $VPS_User@$VPS_Host"
if ($SSH_Key) {
    $SSH_Command += " -i $SSH_Key"
}

# 启动 SSH 进程 (后台运行)
$SSH_Process = Start-Process -FilePath "ssh" -ArgumentList "-N", "-D", "$Local_Port", "$VPS_User@$VPS_Host" -PassThru -NoNewWindow

if ($SSH_Process.Id) {
    Write-Host "SSH 隧道已启动！" -ForegroundColor Green
    Write-Host "本地 SOCKS5 代理: 127.0.0.1:$Local_Port" -ForegroundColor Green
    
    # 设置系统代理 (调用 netsh winhttp set proxy 或者注册表修改)
    # 这里使用简单的注册表修改法，更通用
    try {
        Write-Host "正在配置系统代理..." -ForegroundColor Yellow
        $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        Set-ItemProperty -Path $RegPath -Name ProxyEnable -Value 1
        Set-ItemProperty -Path $RegPath -Name ProxyServer -Value "socks=127.0.0.1:$Local_Port"
        # 刷新系统代理设置 (这步比较 tricky，可能需要重开浏览器)
        Write-Host "系统代理已设置！请重新启动你的浏览器。" -ForegroundColor Green
    }
    catch {
        Write-Error "设置代理失败: $_"
    }

    Write-Host "正在运行中... (关闭此窗口将停止代理)" -ForegroundColor Yellow
    
    # 循环检查 SSH 进程是否还在运行
    while (-not $SSH_Process.HasExited) {
        Start-Sleep -Seconds 2
    }
    
    # 如果进程意外退出
    Write-Warning "SSH 连接已断开！"
    
    # 恢复系统代理设置
    Write-Host "正在恢复系统代理..." -ForegroundColor Yellow
    Set-ItemProperty -Path $RegPath -Name ProxyEnable -Value 0
    Write-Host "代理已关闭。" -ForegroundColor Green
    
    Read-Host "按回车键退出..."
}
else {
    Write-Error "SSH 启动失败！请检查配置。"
    Read-Host "按回车键退出..."
}
