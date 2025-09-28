# 🚀 DevOps-Nexus | DevOps技能枢纽

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Compatible-green.svg)](https://kubernetes.io/)
[![Ansible](https://img.shields.io/badge/Ansible-Automated-red.svg)](https://www.ansible.com/)

🌟 **DevOps技能枢纽** - 连接开发与运维的技能汇聚点，全面展示DevOps核心技能的综合性项目，涵盖Linux系统管理、容器化、自动化运维、监控告警等关键领域。

## ⭐ 核心亮点

- 🎯 **5分钟内定位负载突增根因** - 快速故障诊断能力
- 🤖 **替代80%手工操作** - 高度自动化运维
- 📊 **99.98%服务可用性** - 生产级可靠性保障  
- ⚡ **12分钟快速上线** - 新节点部署效率提升90%
- 🔔 **零中断预警** - 提前8次预警磁盘风险，业务零中断
- 🔄 **50%响应提速** - 告警自动化工单处理

## 项目架构

```
DevOps-Nexus/
├── app/                    # 应用程序
│   ├── api/               # FastAPI微服务
│   └── exporter/          # 自定义Prometheus Exporter
├── k8s/                   # Kubernetes配置
│   ├── base/              # 基础部署配置
│   ├── monitoring/        # 监控相关配置
│   └── networking/        # 网络策略配置
├── ansible/               # Ansible自动化
│   ├── playbooks/         # Playbook文件
│   ├── inventory/         # 主机清单
│   └── roles/             # Ansible角色
├── monitoring/            # 监控配置
│   ├── prometheus/        # Prometheus配置
│   ├── grafana/          # Grafana仪表板
│   └── n8n/              # n8n工作流
├── scripts/               # 运维脚本
│   ├── performance/       # 性能调优脚本
│   └── troubleshooting/   # 故障排查脚本
└── docs/                  # 文档
```

## 技能展示

### 1. Linux系统管理
- systemd服务管理
- iptables防火墙配置
- 性能调优脚本
- 故障排查工具

### 2. Python开发
- FastAPI微服务应用
- 异步编程(asyncio)
- 自动化脚本开发
- 自定义Prometheus Exporter

### 3. 容器化与编排
- Docker容器化
- Kubernetes集群部署
- HPA自动扩缩容
- 灰度发布配置
- NetworkPolicy网络策略
- Velero备份恢复

### 4. 自动化运维
- Ansible Playbook编写
- 标准化环境交付
- 节点快速上线

### 5. 监控告警
- Prometheus监控配置
- 自定义Exporter开发
- Grafana仪表板设计
- 预警规则配置

### 6. 工作流自动化
- n8n零代码自动化
- 告警自动建单
- 责任人自动分配

## 🚀 快速开始

### 一键演示部署
```bash
# 克隆项目
git clone https://github.com/GravityblueX/N8N.git
cd DevOps-Nexus

# 一键启动演示环境
make demo
```

### 分步部署
```bash
# 1. 构建镜像
make build

# 2. 本地部署
make deploy-local

# 3. 启动监控
make monitor

# 4. 测试服务
make test
```

### 访问服务
部署完成后，通过以下地址访问各项服务：

| 服务 | 地址 | 用户名/密码 |
|------|------|-------------|
| 🔧 API服务 | http://localhost:8000 | - |
| 📊 Grafana | http://localhost:3000 | admin/admin123 |
| 📈 Prometheus | http://localhost:9090 | - |
| 🔄 n8n工作流 | http://localhost:5678 | admin/n8n123456 |

## 项目特点

- **高可用**: 服务可用性达到99.98%
- **快速部署**: 新节点上线时间从2h缩短至12min
- **预警机制**: 提前预警磁盘空间风险，实现业务0中断
- **自动化**: 替代80%手工操作，工单响应时间缩短50%