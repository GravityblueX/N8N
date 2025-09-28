#!/bin/bash

# =================================================================
# 快速故障排查脚本 - 5分钟内定位负载突增根因
# DevOps技能展示：故障排查和问题定位能力
# =================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 全局变量
DIAGNOSIS_START_TIME=$(date +%s)
LOG_FILE="/tmp/quick-diagnosis-$(date +%Y%m%d-%H%M%S).log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=85
ALERT_THRESHOLD_DISK=90
ALERT_THRESHOLD_LOAD_MULTIPLIER=2

# 日志函数
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC}  $timestamp - $message" | tee -a "$LOG_FILE" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $timestamp - $message" | tee -a "$LOG_FILE" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
        "ALERT") echo -e "${PURPLE}[ALERT]${NC} $timestamp - $message" | tee -a "$LOG_FILE" ;;
    esac
}

# 获取系统信息
get_system_info() {
    echo "主机名: $(hostname)"
    echo "内核版本: $(uname -r)"
    echo "当前时间: $(date)"
    echo "系统运行时间: $(uptime -p)"
    echo "CPU核心数: $(nproc)"
    echo "总内存: $(free -h | awk 'NR==2{print $2}')"
}

# 检查CPU使用率和负载
check_cpu_load() {
    log "INFO" "检查CPU使用率和系统负载..."
    
    # 获取系统负载
    local load_avg=($(cat /proc/loadavg))
    local load1=${load_avg[0]}
    local load5=${load_avg[1]}
    local load15=${load_avg[2]}
    local cpu_cores=$(nproc)
    local load_threshold=$(echo "$cpu_cores * $ALERT_THRESHOLD_LOAD_MULTIPLIER" | bc)
    
    echo "=== 系统负载分析 ==="
    echo "1分钟负载:  $load1"
    echo "5分钟负载:  $load5"
    echo "15分钟负载: $load15"
    echo "CPU核心数:  $cpu_cores"
    echo "负载阈值:   $load_threshold"
    
    # 检查负载是否过高
    if (( $(echo "$load1 > $load_threshold" | bc -l) )); then
        log "ALERT" "系统负载过高！1分钟负载($load1) > 阈值($load_threshold)"
        
        # 分析高CPU进程
        echo -e "\n=== TOP 10 高CPU进程 ==="
        ps aux --sort=-%cpu | head -11
        
        # 检查CPU使用率分布
        echo -e "\n=== CPU使用率详情 ==="
        top -bn1 | grep "Cpu(s)" | head -1
        
        return 1
    fi
    
    # 获取CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    echo "当前CPU使用率: $cpu_usage%"
    
    if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        log "WARN" "CPU使用率过高: $cpu_usage%"
        return 1
    fi
    
    return 0
}

# 检查内存使用
check_memory_usage() {
    log "INFO" "检查内存使用情况..."
    
    echo "=== 内存使用分析 ==="
    free -h
    
    # 计算内存使用率
    local mem_info=($(free | grep Mem))
    local mem_total=${mem_info[1]}
    local mem_used=${mem_info[2]}
    local mem_available=${mem_info[6]}
    local mem_usage=$(echo "scale=1; $mem_used * 100 / $mem_total" | bc)
    
    echo "内存使用率: $mem_usage%"
    
    if (( $(echo "$mem_usage > $ALERT_THRESHOLD_MEM" | bc -l) )); then
        log "ALERT" "内存使用率过高: $mem_usage%"
        
        # 分析高内存进程
        echo -e "\n=== TOP 10 高内存进程 ==="
        ps aux --sort=-%mem | head -11
        
        # 检查swap使用
        local swap_info=($(free | grep Swap))
        if [[ ${#swap_info[@]} -gt 1 ]] && [[ ${swap_info[1]} -gt 0 ]]; then
            local swap_used=${swap_info[2]}
            local swap_total=${swap_info[1]}
            local swap_usage=$(echo "scale=1; $swap_used * 100 / $swap_total" | bc)
            echo "Swap使用率: $swap_usage%"
            
            if (( $(echo "$swap_usage > 10" | bc -l) )); then
                log "WARN" "Swap使用率较高: $swap_usage%，可能影响性能"
            fi
        fi
        
        return 1
    fi
    
    return 0
}

# 检查磁盘使用和I/O
check_disk_usage() {
    log "INFO" "检查磁盘使用情况..."
    
    echo "=== 磁盘使用分析 ==="
    df -h
    
    local disk_alert=false
    
    # 检查各分区使用率
    while IFS= read -r line; do
        if [[ $line =~ ^/dev/ ]]; then
            local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            local filesystem=$(echo "$line" | awk '{print $1}')
            local mountpoint=$(echo "$line" | awk '{print $6}')
            
            if [[ $usage =~ ^[0-9]+$ ]] && [[ $usage -gt $ALERT_THRESHOLD_DISK ]]; then
                log "ALERT" "磁盘空间严重不足: $mountpoint ($usage%)"
                disk_alert=true
            elif [[ $usage =~ ^[0-9]+$ ]] && [[ $usage -gt 85 ]]; then
                log "WARN" "磁盘空间不足: $mountpoint ($usage%)"
                disk_alert=true
            fi
        fi
    done < <(df -h)
    
    # 检查inode使用率
    echo -e "\n=== inode使用情况 ==="
    df -i | grep -E '^/dev/' | while read line; do
        local inode_usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local mountpoint=$(echo "$line" | awk '{print $6}')
        
        if [[ $inode_usage =~ ^[0-9]+$ ]] && [[ $inode_usage -gt 85 ]]; then
            log "WARN" "inode使用率过高: $mountpoint ($inode_usage%)"
        fi
    done
    
    # 检查磁盘I/O
    if command -v iostat &> /dev/null; then
        echo -e "\n=== 磁盘I/O分析 ==="
        iostat -x 1 2 | tail -n +4
    fi
    
    [[ $disk_alert == false ]]
}

# 检查网络状况
check_network_status() {
    log "INFO" "检查网络状况..."
    
    echo "=== 网络连接统计 ==="
    local total_connections=$(ss -tuln | wc -l)
    echo "总连接数: $total_connections"
    
    # 连接状态统计
    echo -e "\n=== 网络连接状态分布 ==="
    ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -nr
    
    # 检查监听端口
    echo -e "\n=== 监听端口 ==="
    ss -tuln | grep LISTEN
    
    # 检查网络错误
    echo -e "\n=== 网络接口错误统计 ==="
    for interface in $(ls /sys/class/net/ | grep -v lo); do
        local rx_errors=$(cat /sys/class/net/$interface/statistics/rx_errors 2>/dev/null || echo 0)
        local tx_errors=$(cat /sys/class/net/$interface/statistics/tx_errors 2>/dev/null || echo 0)
        local rx_dropped=$(cat /sys/class/net/$interface/statistics/rx_dropped 2>/dev/null || echo 0)
        local tx_dropped=$(cat /sys/class/net/$interface/statistics/tx_dropped 2>/dev/null || echo 0)
        
        if [[ $rx_errors -gt 0 ]] || [[ $tx_errors -gt 0 ]] || [[ $rx_dropped -gt 0 ]] || [[ $tx_dropped -gt 0 ]]; then
            log "WARN" "网络接口 $interface 存在错误或丢包: RX_ERR=$rx_errors TX_ERR=$tx_errors RX_DROP=$rx_dropped TX_DROP=$tx_dropped"
        fi
    done
    
    # 检查连接数是否过多
    if [[ $total_connections -gt 10000 ]]; then
        log "WARN" "网络连接数较高: $total_connections"
        return 1
    fi
    
    return 0
}

# 检查进程状况
check_processes() {
    log "INFO" "检查进程状况..."
    
    echo "=== 进程统计 ==="
    local total_processes=$(ps aux | wc -l)
    local running_processes=$(ps aux | grep -c ' R ' || true)
    local sleeping_processes=$(ps aux | grep -c ' S ' || true)
    local zombie_processes=$(ps aux | grep -c ' Z ' || true)
    
    echo "总进程数: $total_processes"
    echo "运行中: $running_processes"
    echo "睡眠中: $sleeping_processes"
    echo "僵尸进程: $zombie_processes"
    
    # 检查僵尸进程
    if [[ $zombie_processes -gt 0 ]]; then
        log "WARN" "发现 $zombie_processes 个僵尸进程"
        echo -e "\n=== 僵尸进程详情 ==="
        ps aux | grep ' Z '
    fi
    
    # 检查高资源使用进程
    echo -e "\n=== 资源使用TOP5进程 ==="
    echo "CPU TOP5:"
    ps aux --sort=-%cpu | head -6 | tail -5
    echo -e "\n内存TOP5:"
    ps aux --sort=-%mem | head -6 | tail -5
    
    return 0
}

# 检查系统日志
check_system_logs() {
    log "INFO" "检查系统日志..."
    
    echo "=== 最近系统错误日志 ==="
    if command -v journalctl &> /dev/null; then
        journalctl --since "1 hour ago" --priority=err --no-pager | tail -20
    else
        tail -50 /var/log/syslog | grep -i error || true
    fi
    
    echo -e "\n=== 最近内核消息 ==="
    dmesg | tail -20
    
    # 检查OOM killer
    echo -e "\n=== OOM Killer检查 ==="
    if dmesg | grep -i "killed process" | tail -5; then
        log "WARN" "发现OOM Killer活动，系统可能出现内存不足"
    fi
    
    return 0
}

# 检查服务状态
check_critical_services() {
    log "INFO" "检查关键服务状态..."
    
    local critical_services=("sshd" "systemd-networkd" "systemd-resolved" "cron")
    
    echo "=== 关键服务状态 ==="
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo "✓ $service: 运行中"
        else
            log "WARN" "关键服务 $service 未运行"
            echo "✗ $service: 已停止"
        fi
    done
    
    # 检查失败的服务
    echo -e "\n=== 失败的服务 ==="
    systemctl --failed --no-pager
    
    return 0
}

# 快速安全检查
quick_security_check() {
    log "INFO" "执行快速安全检查..."
    
    echo "=== 安全检查 ==="
    
    # 检查登录失败
    echo "最近登录失败尝试:"
    if [[ -f /var/log/auth.log ]]; then
        grep "Failed password" /var/log/auth.log | tail -5 || true
    elif [[ -f /var/log/secure ]]; then
        grep "Failed password" /var/log/secure | tail -5 || true
    fi
    
    # 检查sudo使用
    echo -e "\n最近sudo使用:"
    if command -v journalctl &> /dev/null; then
        journalctl --since "1 hour ago" | grep sudo | tail -5 || true
    fi
    
    # 检查异常网络连接
    echo -e "\n外部连接检查:"
    ss -tuln | grep -E ":(22|80|443|3306|5432)" | head -10
    
    return 0
}

# 生成问题总结
generate_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - DIAGNOSIS_START_TIME))
    
    echo ""
    echo "================================================================="
    echo "                     故障诊断总结报告"
    echo "================================================================="
    echo "诊断时间: $(date)"
    echo "耗时: ${duration}秒"
    echo "日志文件: $LOG_FILE"
    echo ""
    
    # 分析日志中的警告和错误
    local warnings=$(grep -c "\[WARN\]" "$LOG_FILE" || echo 0)
    local errors=$(grep -c "\[ERROR\]" "$LOG_FILE" || echo 0)
    local alerts=$(grep -c "\[ALERT\]" "$LOG_FILE" || echo 0)
    
    echo "发现问题统计:"
    echo "  严重问题: $alerts"
    echo "  错误: $errors"
    echo "  警告: $warnings"
    echo ""
    
    if [[ $alerts -gt 0 ]] || [[ $errors -gt 0 ]]; then
        echo "⚠️  发现严重问题，建议立即处理！"
        echo ""
        echo "严重问题详情:"
        grep -E "\[(ALERT|ERROR)\]" "$LOG_FILE" | tail -10
    elif [[ $warnings -gt 0 ]]; then
        echo "⚠️  发现警告信息，建议关注："
        echo ""
        echo "警告详情:"
        grep "\[WARN\]" "$LOG_FILE" | tail -10
    else
        echo "✅ 系统状态良好，未发现明显问题"
    fi
    
    echo ""
    echo "建议操作:"
    echo "1. 查看完整日志: cat $LOG_FILE"
    echo "2. 持续监控系统指标"
    echo "3. 如有问题，使用 system-tuning.sh 进行优化"
    echo "================================================================="
}

# 主函数
main() {
    echo "================================================================="
    echo "        快速故障诊断工具 - 5分钟内定位负载突增根因"
    echo "================================================================="
    echo ""
    
    log "INFO" "开始系统故障诊断..."
    
    echo "=== 系统基本信息 ==="
    get_system_info
    echo ""
    
    # 执行各项检查
    local check_results=()
    
    # CPU和负载检查
    if check_cpu_load; then
        check_results+=("CPU: ✅")
    else
        check_results+=("CPU: ❌")
    fi
    
    echo ""
    
    # 内存检查
    if check_memory_usage; then
        check_results+=("内存: ✅")
    else
        check_results+=("内存: ❌")
    fi
    
    echo ""
    
    # 磁盘检查
    if check_disk_usage; then
        check_results+=("磁盘: ✅")
    else
        check_results+=("磁盘: ❌")
    fi
    
    echo ""
    
    # 网络检查
    if check_network_status; then
        check_results+=("网络: ✅")
    else
        check_results+=("网络: ❌")
    fi
    
    echo ""
    
    # 进程检查
    check_processes
    check_results+=("进程: ✅")
    
    echo ""
    
    # 服务检查
    check_critical_services
    
    echo ""
    
    # 日志检查
    check_system_logs
    
    echo ""
    
    # 安全检查
    quick_security_check
    
    # 生成总结
    generate_summary
    
    log "INFO" "故障诊断完成"
}

# 信号处理
trap 'log "ERROR" "诊断过程被中断"; exit 1' INT TERM

# 检查必要的工具
missing_tools=()
for tool in bc ps free df ss top; do
    if ! command -v "$tool" &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log "WARN" "缺少工具: ${missing_tools[*]}，某些功能可能受限"
fi

# 执行主函数
main "$@"