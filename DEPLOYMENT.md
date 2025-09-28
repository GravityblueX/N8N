# 部署指南

本文档详细说明如何部署DevOps技能展示项目。

## 📋 前置要求

### 基础环境
- Ubuntu 20.04+ 或其他Linux发行版
- Docker 20.10+
- Docker Compose 2.0+
- Git 2.0+
- Make

### Kubernetes环境（可选）
- Kubernetes 1.24+
- kubectl
- Helm 3.0+

### Python环境（开发）
- Python 3.9+
- pip

## 🚀 快速部署

### 1. 克隆项目
```bash
git clone https://github.com/GravityblueX/N8N.git
cd N8N
```

### 2. 环境配置
```bash
# 复制环境配置文件
cp .env.example .env

# 根据实际情况修改配置
vim .env
```

### 3. 一键部署
```bash
# 查看所有可用命令
make help

# 一键启动演示环境
make demo
```

## 📦 分步部署

### Step 1: 构建镜像
```bash
make build
```

### Step 2: 本地部署
```bash
# 使用Docker Compose部署
make deploy-local

# 检查服务状态
make status
```

### Step 3: 启动监控
```bash
make monitor
```

### Step 4: 测试服务
```bash
make test
```

## ☸️ Kubernetes部署

### 1. 准备Kubernetes集群
确保你有一个运行中的Kubernetes集群并且kubectl已正确配置。

### 2. 部署应用
```bash
# 部署到Kubernetes
make deploy

# 检查Pod状态
kubectl get pods -n devops-showcase
```

### 3. 部署监控组件
```bash
# 部署Prometheus和Grafana
kubectl apply -f k8s/monitoring/
```

## 🔧 Ansible自动化部署

### 1. 准备主机清单
```bash
# 编辑主机清单
vim ansible/inventory/hosts
```

### 2. 运行自动化部署
```bash
# 执行完整部署
make ansible

# 或手动执行
cd ansible
ansible-playbook -i inventory/hosts playbooks/site.yml
```

## 📊 监控配置

### 访问监控面板
部署完成后，可以通过以下地址访问监控服务：

- **Grafana**: http://localhost:3000
  - 用户名: admin
  - 密码: admin123

- **Prometheus**: http://localhost:9090

- **自定义Exporter**: http://localhost:9100/metrics

### 导入仪表板
Grafana仪表板配置文件位于 `monitoring/grafana/dashboards/` 目录。

## 🔄 n8n工作流配置

### 1. 访问n8n
```bash
# 启动n8n服务
cd monitoring/n8n
docker-compose up -d

# 访问地址: http://localhost:5678
# 用户名: admin
# 密码: n8n123456
```

### 2. 导入工作流
1. 登录n8n界面
2. 点击 "Import workflow"
3. 选择 `monitoring/n8n/workflows/alert-automation.json`
4. 配置Webhook URL到Prometheus AlertManager

### 3. 配置外部服务
在工作流中配置以下服务连接：
- Jira API认证
- 飞书Webhook URL
- Prometheus API地址

## 🔒 安全配置

### 1. 防火墙配置
```bash
# 配置iptables防火墙
make firewall

# 或手动执行
sudo ./scripts/performance/iptables-setup.sh setup
```

### 2. SSL证书（生产环境）
```bash
# 使用Let's Encrypt生成证书
certbot --nginx -d your-domain.com
```

### 3. 密钥管理
- 更新 `.env` 文件中的默认密码
- 使用Kubernetes Secrets管理敏感信息
- 配置RBAC权限控制

## 🔍 故障排查

### 常用诊断命令
```bash
# 快速系统诊断
make diagnose

# 查看服务日志
make logs

# 检查服务状态
make status

# 手动运行诊断脚本
./scripts/troubleshooting/quick-diagnosis.sh
```

### 常见问题

#### 1. Docker容器启动失败
```bash
# 检查Docker日志
docker-compose logs

# 重新构建镜像
make build
```

#### 2. Kubernetes Pod无法启动
```bash
# 检查Pod状态
kubectl describe pod <pod-name> -n devops-showcase

# 查看事件
kubectl get events -n devops-showcase
```

#### 3. 监控数据不显示
```bash
# 检查Prometheus targets
curl http://localhost:9090/api/v1/targets

# 重启监控服务
docker-compose restart prometheus grafana
```

## 📈 性能优化

### 系统调优
```bash
# 执行系统性能调优
make tune

# 手动执行调优脚本
sudo ./scripts/performance/system-tuning.sh tune
```

### 监控优化
- 调整Prometheus采集间隔
- 优化Grafana查询性能
- 配置监控数据保留策略

## 🗄️ 备份与恢复

### 数据备份
```bash
# 备份Prometheus数据
docker run --rm -v prometheus-data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz /data

# 备份Grafana配置
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz /data
```

### 恢复数据
```bash
# 恢复Prometheus数据
docker run --rm -v prometheus-data:/data -v $(pwd):/backup alpine tar xzf /backup/prometheus-backup.tar.gz -C /

# 恢复Grafana配置
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine tar xzf /backup/grafana-backup.tar.gz -C /
```

## 📞 技术支持

如果在部署过程中遇到问题，请：

1. 查看项目文档和FAQ
2. 检查系统日志和应用日志
3. 运行诊断脚本排查问题
4. 在GitHub Issues中提交问题

## 🔄 更新升级

### 应用更新
```bash
# 拉取最新代码
git pull origin main

# 重新构建和部署
make build
make deploy-local
```

### 配置更新
```bash
# 重新加载配置
docker-compose restart

# Kubernetes滚动更新
kubectl rollout restart deployment/devops-api -n devops-showcase
```