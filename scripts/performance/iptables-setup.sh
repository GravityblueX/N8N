#!/bin/bash

# =================================================================
# iptables防火墙配置脚本 - DevOps安全技能展示
# 功能：配置生产环境防火墙规则，确保系统安全
# =================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 备份当前iptables规则
backup_iptables() {
    local backup_dir="/etc/iptables/backup"
    local backup_file="$backup_dir/iptables-backup-$(date +%Y%m%d-%H%M%S).rules"
    
    mkdir -p "$backup_dir"
    
    if iptables -L &>/dev/null; then
        iptables-save > "$backup_file"
        log_info "当前iptables规则已备份到: $backup_file"
    fi
}

# 清空现有规则
clear_rules() {
    log_info "清空现有iptables规则..."
    
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -t raw -F
    iptables -t raw -X
}

# 设置默认策略
set_default_policies() {
    log_info "设置默认策略..."
    
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
}

# 基础规则设置
setup_basic_rules() {
    log_info "设置基础防火墙规则..."
    
    # 允许loopback接口
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # 允许已建立的连接
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # 防止无效数据包
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    
    # 防止端口扫描
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
}

# SSH访问控制
setup_ssh_rules() {
    log_info "配置SSH访问规则..."
    
    local ssh_port=${SSH_PORT:-22}
    local allowed_ssh_ips=(
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
    )
    
    # 限制SSH连接频率，防止暴力破解
    iptables -A INPUT -p tcp --dport $ssh_port -m conntrack --ctstate NEW -m recent --set --name ssh
    iptables -A INPUT -p tcp --dport $ssh_port -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name ssh -j DROP
    
    # 允许指定IP段访问SSH
    for ip in "${allowed_ssh_ips[@]}"; do
        iptables -A INPUT -p tcp -s $ip --dport $ssh_port -j ACCEPT
    done
    
    log_info "SSH端口 $ssh_port 访问规则已配置"
}

# Web服务规则
setup_web_rules() {
    log_info "配置Web服务规则..."
    
    # HTTP和HTTPS访问
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # 限制HTTP连接频率，防止DDoS
    iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m recent --set --name http
    iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m recent --update --seconds 1 --hitcount 20 --name http -j DROP
    
    iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m recent --set --name https
    iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -m recent --update --seconds 1 --hitcount 20 --name https -j DROP
}

# 监控服务规则
setup_monitoring_rules() {
    log_info "配置监控服务规则..."
    
    local monitoring_networks=(
        "10.0.1.0/24"  # 监控网段
        "172.16.1.0/24"  # 管理网段
    )
    
    # Prometheus
    for network in "${monitoring_networks[@]}"; do
        iptables -A INPUT -p tcp -s $network --dport 9090 -j ACCEPT  # Prometheus
        iptables -A INPUT -p tcp -s $network --dport 9100 -j ACCEPT  # Node Exporter
        iptables -A INPUT -p tcp -s $network --dport 9323 -j ACCEPT  # Docker metrics
    done
    
    # Grafana
    for network in "${monitoring_networks[@]}"; do
        iptables -A INPUT -p tcp -s $network --dport 3000 -j ACCEPT
    done
    
    # AlertManager
    for network in "${monitoring_networks[@]}"; do
        iptables -A INPUT -p tcp -s $network --dport 9093 -j ACCEPT
    done
}

# Kubernetes规则
setup_k8s_rules() {
    log_info "配置Kubernetes规则..."
    
    local k8s_networks=(
        "10.0.1.0/24"    # K8s节点网段
        "10.244.0.0/16"  # Pod网段
        "10.96.0.0/12"   # Service网段
    )
    
    # API Server
    for network in "${k8s_networks[@]}"; do
        iptables -A INPUT -p tcp -s $network --dport 6443 -j ACCEPT
    done
    
    # etcd
    for network in "${k8s_networks[@]}"; do
        iptables -A INPUT -p tcp -s $network --dport 2379:2380 -j ACCEPT
    done
    
    # kubelet
    for network in "${k8s_networks[@]}"; do
        iptables -A INPUT -p tcp -s $network --dport 10250 -j ACCEPT
    done
    
    # kube-scheduler
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport 10251 -j ACCEPT
    
    # kube-controller-manager
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport 10252 -j ACCEPT
    
    # NodePort范围
    for network in "${k8s_networks[@]}"; do
        iptables -A INPUT -p tcp -s $network --dport 30000:32767 -j ACCEPT
    done
    
    # Flannel VXLAN
    for network in "${k8s_networks[@]}"; do
        iptables -A INPUT -p udp -s $network --dport 8472 -j ACCEPT
    done
}

# DNS规则
setup_dns_rules() {
    log_info "配置DNS规则..."
    
    # 允许DNS查询
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    iptables -A INPUT -p udp --sport 53 -j ACCEPT
    iptables -A INPUT -p tcp --sport 53 -j ACCEPT
}

# NTP规则
setup_ntp_rules() {
    log_info "配置NTP规则..."
    
    # 允许NTP同步
    iptables -A OUTPUT -p udp --dport 123 -j ACCEPT
    iptables -A INPUT -p udp --sport 123 -j ACCEPT
}

# 日志记录规则
setup_logging_rules() {
    log_info "配置日志记录规则..."
    
    # 记录被拒绝的连接（限制频率避免日志洪水）
    iptables -A INPUT -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "iptables-denied: " --log-level 7
    
    # 最终DROP规则
    iptables -A INPUT -j DROP
}

# ICMP规则
setup_icmp_rules() {
    log_info "配置ICMP规则..."
    
    # 允许ping（限制频率）
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
    
    # 允许必要的ICMP类型
    iptables -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type parameter-problem -j ACCEPT
}

# 防DDoS规则
setup_ddos_protection() {
    log_info "配置DDoS防护规则..."
    
    # 限制新连接速率
    iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP
    
    # 防止ping洪水
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    
    # 防止端口扫描
    iptables -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROP
    iptables -A INPUT -m recent --name portscan --remove
    iptables -A INPUT -p tcp -m tcp --dport 139 -m recent --name portscan --set -j LOG --log-prefix "portscan:"
    iptables -A INPUT -p tcp -m tcp --dport 139 -m recent --name portscan --set -j DROP
}

# 保存规则
save_rules() {
    log_info "保存iptables规则..."
    
    # 检查系统类型并保存规则
    if command -v iptables-save &> /dev/null; then
        if [[ -d /etc/iptables ]]; then
            iptables-save > /etc/iptables/rules.v4
        elif [[ -f /etc/sysconfig/iptables ]]; then
            iptables-save > /etc/sysconfig/iptables
        else
            iptables-save > /etc/iptables.rules
        fi
        
        log_info "iptables规则已保存"
    else
        log_warn "无法找到iptables-save命令，规则未持久化"
    fi
}

# 配置开机自启
setup_autostart() {
    log_info "配置iptables开机自启..."
    
    # 创建systemd服务
    cat > /etc/systemd/system/iptables-restore.service << 'EOF'
[Unit]
Description=Restore iptables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable iptables-restore.service
    
    log_info "iptables自启动服务已配置"
}

# 显示当前规则
show_rules() {
    echo ""
    echo "=== 当前iptables规则 ==="
    iptables -L -n -v --line-numbers
    
    echo ""
    echo "=== NAT规则 ==="
    iptables -t nat -L -n -v --line-numbers
}

# 测试规则
test_rules() {
    log_info "测试防火墙规则..."
    
    echo ""
    echo "=== 规则测试结果 ==="
    
    # 测试SSH连接
    if iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null; then
        echo "✓ SSH规则配置正确"
    else
        echo "✗ SSH规则可能有问题"
    fi
    
    # 测试HTTP连接
    if iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null; then
        echo "✓ HTTP规则配置正确"
    else
        echo "✗ HTTP规则可能有问题"
    fi
    
    # 测试HTTPS连接
    if iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null; then
        echo "✓ HTTPS规则配置正确"
    else
        echo "✗ HTTPS规则可能有问题"
    fi
    
    echo ""
    echo "规则统计:"
    echo "INPUT链规则数: $(iptables -L INPUT --line-numbers | wc -l)"
    echo "OUTPUT链规则数: $(iptables -L OUTPUT --line-numbers | wc -l)"
    echo "FORWARD链规则数: $(iptables -L FORWARD --line-numbers | wc -l)"
}

# 生成规则文档
generate_documentation() {
    local doc_file="/etc/iptables/iptables-rules-doc.txt"
    
    cat > "$doc_file" << EOF
=================================================================
iptables防火墙规则文档
生成时间: $(date)
=================================================================

1. 基础安全策略:
   - 默认INPUT策略: DROP
   - 默认FORWARD策略: DROP
   - 默认OUTPUT策略: ACCEPT

2. 允许的服务端口:
   - SSH: 22 (限制来源IP段)
   - HTTP: 80
   - HTTPS: 443
   - Prometheus: 9090 (限制来源)
   - Node Exporter: 9100 (限制来源)
   - Grafana: 3000 (限制来源)

3. Kubernetes端口:
   - API Server: 6443
   - etcd: 2379-2380
   - kubelet: 10250
   - NodePort: 30000-32767

4. 安全防护:
   - SSH暴力破解防护
   - DDoS攻击防护
   - 端口扫描防护
   - 连接频率限制

5. 管理命令:
   - 查看规则: iptables -L -n -v
   - 重载规则: systemctl restart iptables-restore
   - 备份规则: iptables-save > backup.rules
   - 恢复规则: iptables-restore < backup.rules

=================================================================
EOF
    
    log_info "防火墙规则文档已生成: $doc_file"
}

# 主函数
main() {
    echo "================================================================="
    echo "           iptables防火墙配置脚本 - DevOps安全技能展示"
    echo "================================================================="
    
    case "${1:-setup}" in
        "setup")
            check_root
            backup_iptables
            clear_rules
            set_default_policies
            setup_basic_rules
            setup_ssh_rules
            setup_web_rules
            setup_monitoring_rules
            setup_k8s_rules
            setup_dns_rules
            setup_ntp_rules
            setup_icmp_rules
            setup_ddos_protection
            setup_logging_rules
            save_rules
            setup_autostart
            generate_documentation
            show_rules
            test_rules
            log_info "iptables防火墙配置完成！"
            ;;
        "show")
            show_rules
            ;;
        "test")
            test_rules
            ;;
        "backup")
            check_root
            backup_iptables
            ;;
        "restore")
            check_root
            if [[ -n "${2:-}" ]] && [[ -f "$2" ]]; then
                iptables-restore < "$2"
                log_info "iptables规则已从 $2 恢复"
            else
                log_error "请指定备份文件路径"
                exit 1
            fi
            ;;
        "help")
            echo "用法: $0 [setup|show|test|backup|restore|help]"
            echo "  setup   - 配置防火墙规则 (默认)"
            echo "  show    - 显示当前规则"
            echo "  test    - 测试规则配置"
            echo "  backup  - 备份当前规则"
            echo "  restore - 恢复指定备份文件"
            echo "  help    - 显示帮助信息"
            ;;
        *)
            log_error "未知参数: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 检查必要工具
for tool in iptables iptables-save iptables-restore; do
    if ! command -v "$tool" &> /dev/null; then
        log_error "工具 $tool 未安装"
        exit 1
    fi
done

main "$@"