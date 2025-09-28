#!/bin/bash

# =================================================================
# 系统性能调优脚本 - DevOps技能展示
# 功能：5分钟内定位负载突增根因，进行性能优化
# =================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 性能监控和调优函数
check_system_load() {
    log_info "检查系统负载..."
    
    local load1=$(awk '{print $1}' /proc/loadavg)
    local load5=$(awk '{print $2}' /proc/loadavg)
    local load15=$(awk '{print $3}' /proc/loadavg)
    local cpu_cores=$(nproc)
    
    echo "当前系统负载:"
    echo "  1分钟:  $load1"
    echo "  5分钟:  $load5"
    echo "  15分钟: $load15"
    echo "  CPU核心数: $cpu_cores"
    
    # 负载过高预警
    if (( $(echo "$load1 > $cpu_cores * 2" | bc -l) )); then
        log_warn "系统负载过高！1分钟负载($load1)超过CPU核心数($cpu_cores)的2倍"
        return 1
    fi
    
    return 0
}

analyze_cpu_usage() {
    log_info "分析CPU使用情况..."
    
    # CPU使用率分析
    echo "=== CPU使用率分析 ==="
    top -bn1 | head -20
    
    # 高CPU进程识别
    echo -e "\n=== 高CPU使用进程TOP10 ==="
    ps aux --sort=-%cpu | head -11
    
    # CPU上下文切换
    echo -e "\n=== CPU上下文切换统计 ==="
    vmstat 1 3
    
    # 检查CPU steal time (虚拟化环境)
    local steal_time=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | sed 's/%st,//')
    if (( $(echo "$steal_time > 10" | bc -l) )); then
        log_warn "CPU steal time过高($steal_time%)，可能存在虚拟化性能问题"
    fi
}

analyze_memory_usage() {
    log_info "分析内存使用情况..."
    
    echo "=== 内存使用统计 ==="
    free -h
    
    echo -e "\n=== 内存使用详情 ==="
    cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree)"
    
    # 高内存进程分析
    echo -e "\n=== 高内存使用进程TOP10 ==="
    ps aux --sort=-%mem | head -11
    
    # 检查内存碎片
    echo -e "\n=== 内存碎片分析 ==="
    cat /proc/buddyinfo
    
    # 检查swap使用
    local swap_used=$(free | grep Swap | awk '{print $3}')
    local swap_total=$(free | grep Swap | awk '{print $2}')
    if [[ $swap_total -gt 0 ]] && [[ $swap_used -gt 0 ]]; then
        local swap_percent=$(echo "scale=2; $swap_used * 100 / $swap_total" | bc)
        if (( $(echo "$swap_percent > 10" | bc -l) )); then
            log_warn "Swap使用率过高($swap_percent%)，可能影响性能"
        fi
    fi
}

analyze_disk_io() {
    log_info "分析磁盘I/O性能..."
    
    echo "=== 磁盘使用情况 ==="
    df -h
    
    echo -e "\n=== 磁盘I/O统计 ==="
    iostat -x 1 3
    
    echo -e "\n=== 磁盘I/O繁忙进程 ==="
    iotop -bon1 | head -20
    
    # 检查磁盘使用率
    while read line; do
        usage=$(echo $line | awk '{print $5}' | sed 's/%//')
        mountpoint=$(echo $line | awk '{print $6}')
        
        if [[ $usage =~ ^[0-9]+$ ]] && [[ $usage -gt 85 ]]; then
            log_warn "磁盘空间不足: $mountpoint 使用率 $usage%"
        fi
    done < <(df -h | grep -E '^/dev/')
    
    # 检查inode使用率
    echo -e "\n=== inode使用情况 ==="
    df -i
}

analyze_network_performance() {
    log_info "分析网络性能..."
    
    echo "=== 网络接口统计 ==="
    cat /proc/net/dev
    
    echo -e "\n=== 网络连接统计 ==="
    ss -tuln | head -20
    
    echo -e "\n=== 网络连接状态统计 ==="
    netstat -an | awk '/^tcp/ {print $6}' | sort | uniq -c | sort -nr
    
    # 检查网络错误
    echo -e "\n=== 网络错误统计 ==="
    cat /proc/net/snmp | grep -E "(Tcp|Udp)"
    
    # 检查网络丢包
    echo -e "\n=== 网络丢包检查 ==="
    cat /proc/net/dev | awk 'NR>2 {print $1, $4, $12}' | column -t
}

analyze_process_performance() {
    log_info "分析进程性能..."
    
    echo "=== 进程总数统计 ==="
    echo "总进程数: $(ps aux | wc -l)"
    echo "运行中进程: $(ps aux | grep -c ' R ')"
    echo "休眠进程: $(ps aux | grep -c ' S ')"
    echo "僵尸进程: $(ps aux | grep -c ' Z ')"
    
    # 检查僵尸进程
    local zombie_count=$(ps aux | grep -c ' Z ' || true)
    if [[ $zombie_count -gt 0 ]]; then
        log_warn "发现 $zombie_count 个僵尸进程"
        ps aux | grep ' Z '
    fi
    
    echo -e "\n=== 进程文件描述符使用TOP10 ==="
    for pid in $(ps -eo pid --no-headers | head -10); do
        if [[ -d /proc/$pid/fd ]]; then
            fd_count=$(ls /proc/$pid/fd 2>/dev/null | wc -l)
            cmd=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
            echo "$pid $cmd $fd_count"
        fi
    done | sort -k3 -nr | head -10 | column -t
}

quick_performance_diagnosis() {
    log_info "执行5分钟快速性能诊断..."
    
    local start_time=$(date +%s)
    
    echo "=== 系统基本信息 ==="
    echo "主机名: $(hostname)"
    echo "内核版本: $(uname -r)"
    echo "系统时间: $(date)"
    echo "系统运行时间: $(uptime)"
    
    # 1. 检查系统负载 (30秒)
    if ! check_system_load; then
        log_error "系统负载异常，开始详细分析..."
        analyze_cpu_usage
    fi
    
    # 2. 快速CPU分析 (1分钟)
    echo -e "\n=== 快速CPU分析 ==="
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    echo "CPU使用率: $cpu_usage%"
    
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        log_warn "CPU使用率过高，分析高CPU进程..."
        ps aux --sort=-%cpu | head -5
    fi
    
    # 3. 快速内存分析 (30秒)
    echo -e "\n=== 快速内存分析 ==="
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo "内存使用率: $mem_usage%"
    
    if (( $(echo "$mem_usage > 85" | bc -l) )); then
        log_warn "内存使用率过高，分析高内存进程..."
        ps aux --sort=-%mem | head -5
    fi
    
    # 4. 快速磁盘分析 (30秒)
    echo -e "\n=== 快速磁盘分析 ==="
    df -h | grep -E '^/dev/' | while read line; do
        usage=$(echo $line | awk '{print $5}' | sed 's/%//')
        mountpoint=$(echo $line | awk '{print $6}')
        echo "$mountpoint: $usage%"
        
        if [[ $usage =~ ^[0-9]+$ ]] && [[ $usage -gt 90 ]]; then
            log_error "磁盘空间严重不足: $mountpoint ($usage%)"
        fi
    done
    
    # 5. 快速网络分析 (30秒)
    echo -e "\n=== 快速网络分析 ==="
    local conn_count=$(ss -tuln | wc -l)
    echo "网络连接数: $conn_count"
    
    # 6. 快速进程分析 (30秒)
    echo -e "\n=== 快速进程分析 ==="
    local proc_count=$(ps aux | wc -l)
    echo "进程总数: $proc_count"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "快速诊断完成，耗时: ${duration}秒"
}

apply_system_tuning() {
    log_info "应用系统性能调优..."
    
    # 备份当前配置
    backup_dir="/tmp/system-tuning-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 1. 内核参数调优
    log_info "调优内核参数..."
    
    cat > /etc/sysctl.d/99-performance-tuning.conf << 'EOF'
# 网络性能调优
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 32768

# TCP调优
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_syn_backlog = 8192

# 内存管理调优
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
vm.overcommit_memory = 1

# 文件系统调优
fs.file-max = 1000000
fs.nr_open = 1000000
EOF
    
    # 应用内核参数
    sysctl -p /etc/sysctl.d/99-performance-tuning.conf
    
    # 2. 文件描述符限制调优
    log_info "调优文件描述符限制..."
    
    cat >> /etc/security/limits.conf << 'EOF'
# 性能调优 - 文件描述符限制
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
    
    # 3. 系统服务调优
    log_info "调优系统服务..."
    
    # 停用不必要的服务
    for service in bluetooth cups avahi-daemon; do
        if systemctl is-enabled "$service" &>/dev/null; then
            log_info "禁用服务: $service"
            systemctl disable "$service" --now
        fi
    done
    
    # 4. I/O调度器调优
    log_info "调优I/O调度器..."
    
    for disk in $(lsblk -d -o NAME | grep -E '^sd|^nvme' | grep -v 'nvme[0-9]n[0-9]p'); do
        if [[ -f /sys/block/$disk/queue/scheduler ]]; then
            # SSD使用noop，HDD使用deadline
            if [[ $(cat /sys/block/$disk/queue/rotational) == "0" ]]; then
                echo "noop" > /sys/block/$disk/queue/scheduler
                log_info "SSD $disk 使用 noop 调度器"
            else
                echo "deadline" > /sys/block/$disk/queue/scheduler
                log_info "HDD $disk 使用 deadline 调度器"
            fi
        fi
    done
    
    log_info "系统性能调优完成！"
}

generate_performance_report() {
    log_info "生成性能报告..."
    
    local report_file="/tmp/performance-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
=================================================================
系统性能报告 - $(date)
=================================================================

主机信息:
$(hostnamectl)

系统负载:
$(uptime)

CPU信息:
$(lscpu | grep -E "(Model name|CPU\(s\)|Thread|Core)")

内存信息:
$(free -h)

磁盘信息:
$(df -h)

网络信息:
$(ip addr show | grep -E "(inet |link/)")

当前运行进程数: $(ps aux | wc -l)
当前网络连接数: $(ss -tuln | wc -l)

性能建议:
1. 定期清理日志文件
2. 监控磁盘使用率，及时清理或扩容
3. 关注内存使用趋势，考虑是否需要优化应用
4. 定期检查系统负载，避免过载
5. 监控网络连接数，防止连接泄漏

=================================================================
EOF
    
    log_info "性能报告已生成: $report_file"
    echo "报告路径: $report_file"
}

main() {
    echo "==================================================================="
    echo "           系统性能分析与调优工具 - DevOps技能展示"
    echo "==================================================================="
    
    case "${1:-quick}" in
        "quick")
            quick_performance_diagnosis
            ;;
        "full")
            check_system_load
            analyze_cpu_usage
            analyze_memory_usage
            analyze_disk_io
            analyze_network_performance
            analyze_process_performance
            generate_performance_report
            ;;
        "tune")
            if [[ $EUID -ne 0 ]]; then
                log_error "系统调优需要root权限"
                exit 1
            fi
            apply_system_tuning
            ;;
        "help")
            echo "用法: $0 [quick|full|tune|help]"
            echo "  quick - 快速性能诊断 (默认，5分钟内完成)"
            echo "  full  - 完整性能分析"
            echo "  tune  - 应用系统性能调优 (需要root权限)"
            echo "  help  - 显示帮助信息"
            ;;
        *)
            log_error "未知参数: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 检查必要工具
for tool in bc iotop iostat vmstat ss netstat; do
    if ! command -v "$tool" &> /dev/null; then
        log_warn "工具 $tool 未安装，某些功能可能受限"
    fi
done

main "$@"