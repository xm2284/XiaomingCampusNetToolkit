# ============================================================
#  「小明」校园网加速工具箱  (XiaoMing Campus Network Toolkit)
#  Version : 0.1.0-dev
#  License : MIT
#  说明    : 纯本地运行的网络诊断/优化工具，所有修改均可备份与还原
# ============================================================

param(
    [string]$Mode = "menu"   # menu | detect | backup | restore
)

$ErrorActionPreference = "SilentlyContinue"

# ---------- 常量 ----------
$Script:Version   = "0.1.0-dev"
$Script:AppName   = "XiaomingToolkit"
$Script:DataRoot  = Join-Path $env:LOCALAPPDATA $Script:AppName
$Script:BackupDir = Join-Path $Script:DataRoot "backups"
$Script:LogDir    = Join-Path $Script:DataRoot "logs"
$Script:ReportDir = Join-Path $Script:DataRoot "reports"
$Script:ConfigPath= Join-Path $Script:DataRoot "config.json"
$Script:LogPath   = Join-Path $Script:LogDir ("run_{0}.log" -f (Get-Date -Format "yyyyMMdd"))
# 统计服务地址（部署后替换为你的阿里云公网IP/域名）
$Script:TelemetryUrl = "http://47.98.204.220/api/report"
$Script:KeepBackups  = 10

# 跨厂商优化规则表：功能名 -> 候选 RegistryKeyword
$Script:OptRules = [ordered]@{
    "首选频段(5G)"  = @("RoamingPreferredBandType","BandPreference")
    "吞吐量助推器"  = @("ThroughputBoosterEnabled")
    "MIMO节能"      = @("MIMOPowerSaveMode")
    "U-APSD省电"    = @("uAPSDSupport")
    "漫游主动性"    = @("RoamAggressiveness")
    "2.4G信道宽度"  = @("ChannelWidth24")
    "5G信道宽度"    = @("ChannelWidth52")
    "6G信道宽度"    = @("ChannelWidth6")
    "无线模式"      = @("IEEE11nMode","WirelessMode")
    "断开时睡眠"    = @("DeviceSleepOnDisconnect")
    "流控"          = @("*FlowControl","FlowControl")
    "中断调节"      = @("*InterruptModeration","InterruptModeration")
    "接收缓冲区"    = @("*ReceiveBuffers","ReceiveBuffers")
    "发送缓冲区"    = @("*TransmitBuffers","TransmitBuffers")
    "巨型帧"        = @("*JumboPacket","JumboPacket")
    "数据包合并"    = @("*PacketCoalescing","PacketCoalescing")
    "RSC合并"       = @("*RscIPv4","RscIPv4")
    "节能以太网EEE" = @("EEE","EEEPhyEnable","EnableGreenEthernet","EEELinkAdvertisement","AdvancedEEE","GigaLite")
    "超低功耗"      = @("ULPMode")
    "网卡省电"      = @("PowerSavingMode","NicAutoPowerSaver","EnablePowerManagement","AutoPowerSaveModeEnabled")
    "唤醒魔包"      = @("*WakeOnMagicPacket","WakeOnMagicPacket")
}

# ---------- 基础工具 ----------
function Initialize-DataDir {
    foreach($d in @($Script:DataRoot,$Script:BackupDir,$Script:LogDir,$Script:ReportDir)){
        if(-not (Test-Path $d)){ New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}
function Write-Log {
    param([string]$Msg,[string]$Level="INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Level,$Msg
    Add-Content -Path $Script:LogPath -Value $line -Encoding UTF8
}
function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Ensure-Admin {
    if(-not (Test-Admin)){
        Write-Host "需要管理员权限，正在请求..." -ForegroundColor Yellow
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        } catch { Write-Host "已取消提权，操作中止。" -ForegroundColor Red }
        exit
    }
}

# ---------- 配置 / 免责声明 / 遥测开关 ----------
function Get-XmConfig {
    if(Test-Path $Script:ConfigPath){
        try { return Get-Content $Script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }
    # 默认配置：遥测默认开启
    $cfg = [ordered]@{
        DisclaimerAccepted = $false
        AcceptedVersion    = ""
        TelemetryEnabled   = $true
        InstallId          = [guid]::NewGuid().ToString()
        FirstRun           = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    return [PSCustomObject]$cfg
}
function Save-XmConfig {
    param($Config)
    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $Script:ConfigPath -Encoding UTF8
}
function Show-Disclaimer {
    $cfg = Get-XmConfig
    if($cfg.DisclaimerAccepted -and $cfg.AcceptedVersion -eq $Script:Version){ return $true }
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "            「小明」校园网加速工具箱  v$($Script:Version)" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  【免责声明 / 使用须知】" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. 本工具完全免费、开源，仅用于本机网络的诊断与优化，不会访问、"
    Write-Host "     上传任何账号、密码、浏览记录或个人文件。"
    Write-Host "  2. 工具会修改网卡高级属性、TCP 参数等系统网络设置。虽然所有操作"
    Write-Host "     均可备份与一键还原，但仍建议你在执行优化前先创建备份点。"
    Write-Host "  3. 本工具无法突破学校网关对账号的带宽上限，也不保证一定提速；"
    Write-Host "     因使用本工具产生的任何后果由使用者自行承担。"
    Write-Host "  4. 代理清理、网络重置等功能请在理解其作用后使用。"
    Write-Host ""
    Write-Host "  【匿名统计】工具默认开启匿名使用统计（仅含系统版本、网卡厂商、" -ForegroundColor DarkGray
    Write-Host "   优化结果、延迟改善等汇总数据，不含 IP/主机名/MAC/账号），用于" -ForegroundColor DarkGray
    Write-Host "   改进工具；你可随时在[设置]中关闭。" -ForegroundColor DarkGray
    Write-Host ""
    $ans = Read-Host "  是否同意以上条款并继续？(输入 Y 同意，其他键退出)"
    if($ans -eq "Y" -or $ans -eq "y"){
        $cfg.DisclaimerAccepted = $true
        $cfg.AcceptedVersion = $Script:Version
        Save-XmConfig $cfg
        Write-Log "用户同意免责声明"
        Start-Sleep -Seconds 1
        return $true
    }
    Write-Host "  你未同意声明，工具将退出。" -ForegroundColor Red
    Start-Sleep -Seconds 2
    return $false
}

# ---------- 硬件探测 / 能力画像 ----------
function Get-XmVendor {
    param([string]$Desc)
    switch -Regex ($Desc){
        "Intel" {"Intel"}
        "Realtek|RTL" {"Realtek"}
        "MediaTek|MT[0-9]" {"MediaTek"}
        "Qualcomm|Atheros|Killer" {"Qualcomm/Killer"}
        "Broadcom" {"Broadcom"}
        default {"未知/其他"}
    }
}
function Get-XmHardware {
    $list = @()
    foreach($ad in (Get-NetAdapter -Physical)){
        $isWifi = ($ad.PhysicalMediaType -match "802.11") -or ($ad.InterfaceDescription -match "Wi-Fi|Wireless|无线")
        $type = if($isWifi){"无线"}else{"有线"}
        $props = @(Get-NetAdapterAdvancedProperty -Name $ad.Name)
        $cap = @()
        foreach($func in $Script:OptRules.Keys){
            $found = $null
            foreach($kw in $Script:OptRules[$func]){
                if($kw.StartsWith("*")){
                    $real=$kw.TrimStart("*")
                    $found = $props | Where-Object { $_.RegistryKeyword -like "*$real" } | Select-Object -First 1
                } else {
                    $found = $props | Where-Object { $_.RegistryKeyword -eq $kw } | Select-Object -First 1
                }
                if($found){ break }
            }
            if($found){
                $cap += [PSCustomObject]@{
                    Function=$func; Keyword=$found.RegistryKeyword
                    DisplayValue=$found.DisplayValue; RegistryValue=$found.RegistryValue
                }
            }
        }
        $list += [PSCustomObject]@{
            Name=$ad.Name; Description=$ad.InterfaceDescription
            Vendor=(Get-XmVendor $ad.InterfaceDescription); Type=$type
            Status=$ad.Status; LinkSpeed=$ad.LinkSpeed
            Capabilities=$cap
        }
    }
    return $list
}
function Show-Hardware {
    $hw = Get-XmHardware
    foreach($a in $hw){
        Write-Host ""
        Write-Host ("  [{0}] {1} | {2} | {3} | {4} | {5}" -f $a.Type,$a.Name,$a.Vendor,$a.Status,$a.LinkSpeed,$a.Description) -ForegroundColor Cyan
        Write-Host ("       支持优化项 {0} 个:" -f $a.Capabilities.Count)
        foreach($c in $a.Capabilities){
            Write-Host ("        - {0,-12} 当前=""{1}""" -f $c.Function,$c.DisplayValue)
        }
    }
    return $hw
}

# ---------- 备份引擎 ----------
function New-XmBackup {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $dir = Join-Path $Script:BackupDir $stamp
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    # 1) 网卡完整高级属性
    $adapters = @()
    foreach($ad in (Get-NetAdapter -Physical)){
        $props = @()
        foreach($p in (Get-NetAdapterAdvancedProperty -Name $ad.Name)){
            $props += [PSCustomObject]@{
                DisplayName=$p.DisplayName; DisplayValue=$p.DisplayValue
                RegistryKeyword=$p.RegistryKeyword; RegistryValue=$p.RegistryValue
                ValidDisplayValues=$p.ValidDisplayValues; ValidRegistryValues=$p.ValidRegistryValues
            }
        }
        $adapters += [PSCustomObject]@{
            Name=$ad.Name; Description=$ad.InterfaceDescription
            Status=$ad.Status; LinkSpeed=$ad.LinkSpeed; Properties=$props
        }
    }
    $adapters | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $dir "adapters.json") -Encoding UTF8

    # 2) TCP 全局/补充参数
    (netsh int tcp show global) 2>$null | Set-Content (Join-Path $dir "tcp_global.txt") -Encoding UTF8
    (netsh int tcp show supplemental) 2>$null | Set-Content (Join-Path $dir "tcp_supplemental.txt") -Encoding UTF8

    # 3) 代理设置（HKCU + WinHTTP + 环境变量）
    $ie = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $proxy = [ordered]@{
        ProxyEnable=$ie.ProxyEnable; ProxyServer=$ie.ProxyServer; AutoConfigURL=$ie.AutoConfigURL
        WinHttp=((netsh winhttp show proxy) 2>$null | Out-String)
        UserEnv=[ordered]@{
            HTTP_PROXY=[Environment]::GetEnvironmentVariable("HTTP_PROXY","User")
            HTTPS_PROXY=[Environment]::GetEnvironmentVariable("HTTPS_PROXY","User")
        }
        MachineEnv=[ordered]@{
            HTTP_PROXY=[Environment]::GetEnvironmentVariable("HTTP_PROXY","Machine")
            HTTPS_PROXY=[Environment]::GetEnvironmentVariable("HTTPS_PROXY","Machine")
        }
    }
    [PSCustomObject]$proxy | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dir "proxy.json") -Encoding UTF8

    # 4) 各接口 Nagle/TCP 自定义注册表值
    $ifRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $ifs = @()
    foreach($k in (Get-ChildItem $ifRoot)){
        $v = Get-ItemProperty $k.PSPath
        $pick = [ordered]@{}
        foreach($n in @("TcpAckFrequency","TCPNoDelay","TCPDelAckTicks","TcpInitialRTT")){
            if($null -ne $v.$n){ $pick[$n]=$v.$n }
        }
        if($pick.Count){ $ifs += [PSCustomObject]@{ Key=$k.PSChildName; Values=$pick } }
    }
    $ifs | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dir "interfaces_nagle.json") -Encoding UTF8

    # 5) 清单
    $os = Get-CimInstance Win32_OperatingSystem
    $manifest = [ordered]@{
        BackupTime=(Get-Date -Format "yyyy-MM-dd HH:mm:ss"); ToolVersion=$Script:Version
        OS=$os.Caption; Build=$os.BuildNumber; Arch=$os.OSArchitecture
        ComputerName=$env:COMPUTERNAME
        Adapters=($adapters | ForEach-Object { "{0}({1})" -f $_.Name,$_.Description })
        Files=@("adapters.json","tcp_global.txt","tcp_supplemental.txt","proxy.json","interfaces_nagle.json")
    }
    [PSCustomObject]$manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dir "manifest.json") -Encoding UTF8

    # 备份保留策略
    $all = Get-ChildItem $Script:BackupDir -Directory | Sort-Object Name -Descending
    if($all.Count -gt $Script:KeepBackups){
        $all | Select-Object -Skip $Script:KeepBackups | Remove-Item -Recurse -Force
    }
    Write-Log "创建备份点 $stamp"
    return $dir
}

function Get-XmBackups {
    if(-not (Test-Path $Script:BackupDir)){ return @() }
    return @(Get-ChildItem $Script:BackupDir -Directory | Sort-Object Name -Descending)
}

function Restore-XmBackup {
    param([string]$BackupDir)
    if(-not (Test-Path (Join-Path $BackupDir "adapters.json"))){
        Write-Host "备份不完整，缺少 adapters.json" -ForegroundColor Red; return $false
    }
    if(-not (Test-Admin)){ Ensure-Admin }
    $adapters = Get-Content (Join-Path $BackupDir "adapters.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $ok=0; $skip=0
    foreach($a in $adapters){
        if(-not (Get-NetAdapter -Name $a.Name -ErrorAction SilentlyContinue)){ $skip++; continue }
        foreach($p in $a.Properties){
            try {
                # RegistryValue 以字符串数组形式存储：单元素解包为标量，多元素保留数组
                $val = $p.RegistryValue
                if($null -ne $val){
                    $arr = @($val)
                    if($arr.Count -eq 1){ $val = $arr[0] } else { $val = [object[]]$arr }
                }
                Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $p.RegistryKeyword -RegistryValue $val -NoRestart -ErrorAction Stop
                $ok++
            } catch { $skip++ }
        }
    }
    # 还原 Nagle 接口值：先清空优化期写入的值，再按备份重建（确保干净还原）
    $naglePath = Join-Path $BackupDir "interfaces_nagle.json"
    $ifRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    foreach($k in (Get-ChildItem $ifRoot)){
        foreach($n in @("TcpAckFrequency","TCPNoDelay","TCPDelAckTicks","TcpInitialRTT")){
            Remove-ItemProperty -Path $k.PSPath -Name $n -ErrorAction SilentlyContinue
        }
    }
    if(Test-Path $naglePath){
        $ifs = Get-Content $naglePath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach($i in $ifs){
            $reg = "$ifRoot\$($i.Key)"
            if(Test-Path $reg){
                foreach($prop in $i.Values.PSObject.Properties){
                    New-ItemProperty -Path $reg -Name $prop.Name -Value $prop.Value -PropertyType DWord -Force | Out-Null
                }
            }
        }
    }
    Write-Log "从备份恢复: $BackupDir (成功$ok 跳过$skip)"
    Write-Host ("网卡属性恢复完成：成功 {0} 项，跳过 {1} 项。建议重连网卡/重启。" -f $ok,$skip) -ForegroundColor Green
    return $true
}

# ---------- 遥测（默认开启，失败静默，绝不影响主功能） ----------
function Send-XmTelemetry {
    param([hashtable]$Payload)
    $cfg = Get-XmConfig
    if(-not $cfg.TelemetryEnabled){ return }
    try {
        $body = @{
            install_id=$cfg.InstallId; tool_version=$Script:Version
            os=(Get-CimInstance Win32_OperatingSystem).Caption
            build=(Get-CimInstance Win32_OperatingSystem).BuildNumber
            report_time=(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        foreach($k in $Payload.Keys){ $body[$k]=$Payload[$k] }
        Invoke-RestMethod -Uri $Script:TelemetryUrl -Method Post -ContentType "application/json" `
            -Body ($body | ConvertTo-Json -Depth 6) -TimeoutSec 3 | Out-Null
    } catch { Write-Log "遥测上报失败(已忽略): $($_.Exception.Message)" "WARN" }
}

# ---------- 延迟测试 ----------
function Get-XmGateway {
    $r = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
         Where-Object { $_.NextHop -ne "0.0.0.0" -and $_.NextHop } | Sort-Object RouteMetric | Select-Object -First 1
    if($r){ return $r.NextHop }
    $ipc = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
    if($ipc){ return $ipc.IPv4DefaultGateway.NextHop }
    return $null
}
function Test-XmPing {
    param([string]$Addr,[int]$Count=20)
    $reply = Test-Connection -ComputerName $Addr -Count $Count -ErrorAction SilentlyContinue
    $times = @($reply | ForEach-Object { $_.ResponseTime })
    if($times.Count){
        $recv=$times.Count; $loss=[math]::Round(100*(($Count-$recv)/$Count),1)
        $avg=[math]::Round(($times|Measure-Object -Average).Average,1)
        $min=($times|Measure-Object -Minimum).Minimum
        $max=($times|Measure-Object -Maximum).Maximum
        $jit=0.0
        if($recv -ge 2){
            $d=@(); for($i=1;$i -lt $recv;$i++){ $d += [math]::Abs($times[$i]-$times[$i-1]) }
            $jit=[math]::Round(($d|Measure-Object -Average).Average,1)
        }
        return [PSCustomObject]@{Target=$Addr;Sent=$Count;Recv=$recv;Loss=$loss;Min=$min;Max=$max;Avg=$avg;Jitter=$jit}
    }
    # 回退 ping.exe（兼容中英文系统）
    $out = (ping -n $Count -w 1000 $Addr) 2>$null | Out-String
    $loss=100.0
    if($out -match "(\d+)%.*(?:loss|丢失)"){ $loss=[double]$Matches[1] }
    $min=$max=$avg=$null
    if($out -match '(?i)(minimum|最短)\s*=\s*(\d+)\s*ms.*?(maximum|最长)\s*=\s*(\d+)\s*ms.*?(average|平均)\s*=\s*(\d+)\s*ms'){
        $min=[double]$Matches[2]; $max=[double]$Matches[4]; $avg=[double]$Matches[6]
    }
    return [PSCustomObject]@{Target=$Addr;Sent=$Count;Recv=0;Loss=[math]::Round($loss,1);Min=$min;Max=$max;Avg=$avg;Jitter=0}
}
function Get-XmWirelessInfo {
    $w = netsh wlan show interfaces 2>$null | Out-String
    if(-not $w -or $w -notmatch "SSID"){ return "（有线/未连接Wi-Fi）" }
    function m($p){ $mm=[regex]::Match($w,$p); if($mm.Success){$mm.Groups[1].Value.Trim()}else{"-"} }
    return ("SSID={0} 频段={1} 信号={2} 下行={3}Mbps" -f (m "SSID\s*:\s*([^\r\n]+)"),(m "Band\s*:\s*([^\r\n]+)"),(m "Signal\s*:\s*([^\r\n]+)"),(m "Receive rate[^\r\n]*?:\s*([\d.]+)"))
}
function Test-XmLatency {
    param([int]$Count=20)
    $targets=@()
    $gw=Get-XmGateway; if($gw){ $targets+=[pscustomobject]@{Name="网关";Addr=$gw} }
    $fast=@()
    foreach($d in @("223.5.5.5","119.29.29.29","1.1.1.1","114.114.114.114")){
        $o=(ping -n 1 -w 800 $d) 2>$null | Out-String
        if($o -match "TTL="){ $fast+=$d; if($fast.Count -ge 2){break} }
    }
    foreach($d in $fast){ $targets+=[pscustomobject]@{Name="DNS";Addr=$d} }
    $results=@()
    foreach($t in $targets){
        $r=Test-XmPing -Addr $t.Addr -Count $Count
        $r | Add-Member -NotePropertyName Label -NotePropertyValue $t.Name
        $results+=$r
    }
    return [PSCustomObject]@{Time=(Get-Date -Format "HH:mm:ss");Results=$results;Wifi=(Get-XmWirelessInfo)}
}
function Show-XmLatency {
    param($L)
    Write-Host ("  [{0}] {1}" -f $L.Time,$L.Wifi)
    Write-Host ("  {0,-18} {1,7} {2,7} {3,7} {4,7} {5,7}" -f "目标","最小","平均","最大","抖动","丢包%")
    foreach($r in $L.Results){
        $f={param($v) if($null -eq $v){"-"}else{"$v"}}
        Write-Host ("  {0,-18} {1,7} {2,7} {3,7} {4,7} {5,7}" -f "$($r.Label) $($r.Target)",(&$f $r.Min),(&$f $r.Avg),(&$f $r.Max),$r.Jitter,$r.Loss)
    }
}

# ---------- 一键代理清理 ----------
function Clear-XmProxy {
    Write-Host "  [1/5] 关闭系统代理..."
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
    Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name AutoConfigURL -ErrorAction SilentlyContinue
    Write-Host "  [2/5] 重置 WinHTTP 代理..."
    netsh winhttp reset proxy | Out-Null
    Write-Host "  [3/5] 清理用户/系统环境变量代理..."
    foreach($u in @("User","Machine")){
        [Environment]::SetEnvironmentVariable("HTTP_PROXY",$null,$u)
        [Environment]::SetEnvironmentVariable("HTTPS_PROXY",$null,$u)
        [Environment]::SetEnvironmentVariable("http_proxy",$null,$u)
        [Environment]::SetEnvironmentVariable("https_proxy",$null,$u)
    }
    Write-Host "  [4/5] 通知系统刷新设置 + 刷新DNS..."
    try{
        if(-not ("WinINet.Native" -as [type])){
            Add-Type -Namespace WinINet -Name Native -MemberDefinition '[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr h,int o,IntPtr b,int l);'
        }
        [WinINet.Native]::InternetSetOption([IntPtr]::Zero,39,[IntPtr]::Zero,0)|Out-Null
        [WinINet.Native]::InternetSetOption([IntPtr]::Zero,37,[IntPtr]::Zero,0)|Out-Null
    } catch { Write-Log "InternetSetOption失败: $($_.Exception.Message)" "WARN" }
    ipconfig /flushdns | Out-Null
    Write-Host "  [5/5] 验证连通性..."
    Start-Sleep -Milliseconds 600
    $ok = (Test-Connection 223.5.5.5 -Count 2 -Quiet -ErrorAction SilentlyContinue) -or
          ((ping -n 2 -w 1000 223.5.5.5) 2>$null | Out-String -match "TTL=")
    if($ok){ Write-Host "  -> 代理已清理，网络连通正常。" -ForegroundColor Green }
    else   { Write-Host "  -> 代理已清理。若仍打不开网页，请关闭并重新打开浏览器。" -ForegroundColor Yellow }
    $ven = Get-XmVendor ((Get-NetAdapter -Physical | Select-Object -First 1).InterfaceDescription)
    Send-XmTelemetry @{mode="proxy_clean";success=1;opt_count=3;vendor=$ven}
}

# ---------- Nagle 禁用（跨厂商通用，注册表接口级） ----------
function Disable-XmNagle {
    $ifRoot="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    foreach($k in (Get-ChildItem $ifRoot)){
        New-ItemProperty -Path $k.PSPath -Name TcpAckFrequency -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $k.PSPath -Name TCPNoDelay   -Value 1 -PropertyType DWord -Force | Out-Null
    }
}

# ---------- 按"显示值语义"自适应设置网卡高级属性（跨厂商） ----------
function Set-XmAdapterGoal {
    param([string]$Adapter,[PSObject]$Cap,[hashtable]$Goal)
    $props = Get-NetAdapterAdvancedProperty -Name $Adapter -RegistryKeyword $Cap.Keyword -ErrorAction SilentlyContinue
    if(-not $props){ return $false }
    $vals=@($props.ValidRegistryValues); $disps=@($props.ValidDisplayValues)
    if(-not $vals.Count){ return $false }
    $chosen=$null
    if($Goal.WantDisable){
        for($i=0;$i -lt $disps.Count;$i++){ if($disps[$i] -match "禁用|关闭|Disable|Off|无|Offload|关闭"){ $chosen=$vals[$i]; break } }
        if(-not $chosen){ $chosen=$vals[0] }
    } elseif($Goal.WantEnable){
        for($i=0;$i -lt $disps.Count;$i++){ if($disps[$i] -match "启用|Enable|On"){ $chosen=$vals[$i]; break } }
        if(-not $chosen){ $chosen=$vals[-1] }
    } elseif($Goal.WantLike){
        for($i=0;$i -lt $disps.Count;$i++){ if($disps[$i] -like $Goal.WantLike){ $chosen=$vals[$i]; break } }
    }
    if($null -eq $chosen){ return $false }
    $arr=@($chosen); $v = if($arr.Count -eq 1){$arr[0]}else{[object[]]$arr}
    Set-NetAdapterAdvancedProperty -Name $Adapter -RegistryKeyword $Cap.Keyword -RegistryValue $v -NoRestart -ErrorAction Stop
    return $true
}

# ---------- 优化主流程：备份 -> 基线 -> 优化 -> 重启网卡 -> 复测对比 ----------
function Invoke-XmOptimization {
    param([ValidateSet("campus","gaming")][string]$Profile)
    Ensure-Admin
    Clear-Host
    $pName = if($Profile -eq "gaming"){"游戏"}else{"校园网"}
    Write-Host "  ==== 进入 $pName 优化模式 ====" -ForegroundColor Cyan
    Write-Host "  [0/4] 自动创建备份点（可一键还原）..." -ForegroundColor Yellow
    $bk = New-XmBackup
    Write-Host "      备份: $bk"
    Write-Host "  [1/4] 测量优化前延迟（基线，约几秒）..."
    $before = Test-XmLatency -Count 20
    Show-XmLatency $before
    Write-Host "  [2/4] 应用优化..." -ForegroundColor Yellow
    $hw = Get-XmHardware; $applied=0
    foreach($ad in $hw){
        foreach($c in $ad.Capabilities){
            $goal=$null
            switch -Regex ($c.Function){
                "MIMO节能|U-APSD|断开时睡眠|网卡省电|节能以太网EEE|超低功耗|数据包合并" { $goal=@{WantDisable=$true} }
                "首选频段" { if($Profile -eq "gaming" -or $ad.Type -eq "无线"){ $goal=@{WantLike="*5*"} } }
                "吞吐量助推器" { if($Profile -eq "gaming"){ $goal=@{WantEnable=$true} } }
            }
            if($goal){
                try{ if(Set-XmAdapterGoal $ad.Name $c $goal){ $applied++; Write-Host ("      [OK] {0}" -f $c.Function) -ForegroundColor Gray } }
                catch{ Write-Host ("      [跳过] {0}" -f $c.Function) -ForegroundColor DarkGray }
            }
        }
    }
    Disable-XmNagle
    $applied++
    Write-Host "      [OK] Nagle 算法（降低游戏/网页小包延迟）"
    Write-Host "  [3/4] 重启活动网卡使设置生效（Wi-Fi 会自动重连，约5-10秒）..." -ForegroundColor Yellow
    foreach($ad in (Get-NetAdapter -Physical | Where-Object {$_.Status -eq "Up"})){
        Restart-NetAdapter -Name $ad.Name -Confirm:$false -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 10
    Write-Host "  [4/4] 复测延迟..."
    $after = Test-XmLatency -Count 20
    Show-XmLatency $after
    # 对比（网关行）
    $gb=($before.Results|Where-Object{$_.Label -eq "网关"}|Select-Object -First 1).Avg
    $ga=($after.Results|Where-Object{$_.Label -eq "网关"}|Select-Object -First 1).Avg
    Write-Host "  ------------------------------------------------------------" -ForegroundColor Cyan
    if($gb -and $ga){
        $delta=[math]::Round($ga-$gb,1)
        $pct= if($gb){[math]::Round(100*($gb-$ga)/$gb,1)}else{0}
        $arrow= if($delta -le 0){"下降"}else{"上升"}
        Write-Host ("  网关延迟: {0} ms  ->  {1} ms  ({2} {3} ms / {4:0.##}%)" -f $gb,$ga,$arrow,[math]::Abs($delta),$pct) -ForegroundColor Green
    } else { Write-Host "  （未能取得网关延迟，对比仅供参考）" }
    Write-Host "  提示：延迟受网络波动影响，结果仅供参考；如不满意可在菜单选[7]从备份恢复。" -ForegroundColor DarkGray
    # 报告存盘
    $rp=[pscustomobject]@{Profile=$Profile;Backup=$bk;Time=(Get-Date -Format "yyyy-MM-dd HH:mm:ss");Before=$before;After=$after}
    $rp | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $Script:ReportDir ("compare_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))) -Encoding UTF8
    $ven = if($hw.Count){$hw[0].Vendor}else{"Unknown"}
    $at  = if($hw.Count -and $hw[0].Type -eq "无线"){"wireless"}else{"wired"}
    Send-XmTelemetry @{mode=$Profile;success=1;opt_count=$applied;vendor=$ven;adapter_type=$at;latency_before=$gb;latency_after=$ga}
    Start-Sleep -Seconds 2
}

# ---------- 菜单 ----------
function Show-Menu {
    Initialize-DataDir
    if(-not (Show-Disclaimer)){ exit }
    while($true){
        Clear-Host
        Write-Host ""
        Write-Host "  ============================================================" -ForegroundColor Cyan
        Write-Host "        「小明」校园网加速工具箱  v$Script:Version" -ForegroundColor Cyan
        Write-Host "  ============================================================" -ForegroundColor Cyan
        Write-Host "    [1] 硬件探测与优化能力画像"
        Write-Host "    [2] 一键修复代理残留（重启后打不开网页用这个）"
        Write-Host "    [3] 延迟测试（延迟对比参考）"
        Write-Host "    [4] 校园网优化模式（自动备份+优化+复测对比）"
        Write-Host "    [5] 游戏优化模式（保守安全）"
        Write-Host "    [6] 创建备份点"
        Write-Host "    [7] 从备份恢复"
        Write-Host "    [8] 查看当前网络状态"
        Write-Host "    [9] 设置"
        Write-Host "    [0] 退出"
        Write-Host "  ------------------------------------------------------------"
        $cfg = Get-XmConfig
        $tel = if($cfg.TelemetryEnabled){"开启"}else{"关闭"}
        Write-Host ("    匿名统计: {0}    数据在: %LOCALAPPDATA%\XiaomingToolkit" -f $tel) -ForegroundColor DarkGray
        $sel = Read-Host "  请输入选项"
        switch($sel){
            "1" { Clear-Host; Show-Hardware | Out-Null; pause }
            "2" { Ensure-Admin; Clear-Host; Write-Host "`n  ==== 代理残留清理 ====" -ForegroundColor Cyan; Clear-XmProxy; pause }
            "3" { Clear-Host; Write-Host "`n  延迟测试中...`n" -ForegroundColor Yellow; $l=Test-XmLatency -Count 20; Show-XmLatency $l; Write-Host "`n"; pause }
            "4" { Invoke-XmOptimization -Profile campus; pause }
            "5" { Invoke-XmOptimization -Profile gaming; pause }
            "6" { Ensure-Admin; $d=New-XmBackup; Clear-Host; Write-Host "`n  备份点已创建: $d`n" -ForegroundColor Green; pause }
            "7" {
                $bks=Get-XmBackups
                if(-not $bks.Count){ Write-Host "`n  暂无备份点。`n"; pause; continue }
                Clear-Host; Write-Host "`n  可用备份点:"
                for($i=0;$i -lt $bks.Count;$i++){ Write-Host ("   [{0}] {1}" -f ($i+1),$bks[$i].Name) }
                $pick=Read-Host "  输入序号恢复(其他键返回)"
                $n=0; if([int]::TryParse($pick,[ref]$n) -and $n -ge 1 -and $n -le $bks.Count){
                    Restore-XmBackup $bks[$n-1].FullName
                    Write-Host "  已恢复，建议重连网卡以生效。" -ForegroundColor Yellow; pause
                }
            }
            "8" {
                Clear-Host
                $px=Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
                Write-Host "`n  系统代理开关: $($px.ProxyEnable)   代理地址: '$($px.ProxyServer)'"
                ipconfig | Select-String "IPv4|默认网关|Default Gateway"
                Write-Host ""; netsh wlan show interfaces | Select-String "SSID|Band|Channel|Signal|Receive rate|Transmit rate"
                pause
            }
            "9" {
                Clear-Host
                $c=Get-XmConfig
                Write-Host "`n    [1] 匿名统计: $(if($c.TelemetryEnabled){'开启'}else{'关闭'})  (按1切换)"
                Write-Host "    [2] 打开数据文件夹 ($($Script:DataRoot))"
                Write-Host "    [其他键] 返回"
                $s=Read-Host "  选项"
                if($s -eq "1"){ $c.TelemetryEnabled=-not $c.TelemetryEnabled; Save-XmConfig $c; Write-Host "已切换为: $(if($c.TelemetryEnabled){'开启'}else{'关闭'})"; Start-Sleep 1 }
                if($s -eq "2"){ explorer.exe $Script:DataRoot }
            }
            "0" { exit }
        }
    }
}

# ---------- 入口 ----------
Initialize-DataDir
Write-Log "===== 工具箱启动 mode=$Mode ====="
switch($Mode){
    "detect" { Show-Hardware | Out-Null }
    "latency" { $l=Test-XmLatency -Count 20; Show-XmLatency $l }
    "proxy"   { Clear-XmProxy }
    "optcampus" { Invoke-XmOptimization -Profile campus }
    "optgaming" { Invoke-XmOptimization -Profile gaming }
    "backup" { $d=New-XmBackup; Write-Host "备份完成: $d" }
    "restore" {
        $bks=Get-XmBackups
        if($bks.Count){ Restore-XmBackup $bks[0].FullName } else { Write-Host "暂无备份" }
    }
    default { Show-Menu }
}