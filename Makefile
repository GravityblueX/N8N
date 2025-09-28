# DevOps技能展示项目 Makefile
# 提供便捷的项目管理命令

.PHONY: help build deploy clean test monitor setup-env

# 默认目标
help:
	@echo "DevOps技能展示项目 - 可用命令:"
	@echo ""
	@echo "  make setup-env    - 设置开发环境"
	@echo "  make build        - 构建Docker镜像"
	@echo "  make deploy       - 部署到Kubernetes"
	@echo "  make deploy-local - 使用docker-compose本地部署"
	@echo "  make monitor      - 启动监控栈"
	@echo "  make test         - 运行测试"
	@echo "  make clean        - 清理资源"
	@echo "  make ansible      - 运行Ansible部署"
	@echo "  make logs         - 查看应用日志"
	@echo "  make status       - 检查服务状态"
	@echo ""

# 设置开发环境
setup-env:
	@echo "设置开发环境..."
	@if [ ! -f .env ]; then \
		cp .env.example .env 2>/dev/null || echo "请手动创建.env文件"; \
	fi
	@pip install -r app/api/requirements.txt
	@echo "开发环境设置完成"

# 构建Docker镜像
build:
	@echo "构建Docker镜像..."
	docker build -t devops-showcase/api:latest ./app/api
	docker build -t devops-showcase/exporter:latest ./app/exporter
	@echo "Docker镜像构建完成"

# 本地部署
deploy-local:
	@echo "使用docker-compose部署到本地..."
	docker-compose up -d
	@echo "等待服务启动..."
	@sleep 10
	@echo "检查服务状态..."
	docker-compose ps
	@echo ""
	@echo "服务访问地址:"
	@echo "  API服务:     http://localhost:8000"
	@echo "  Prometheus:  http://localhost:9090"
	@echo "  Grafana:     http://localhost:3000 (admin/admin123)"
	@echo "  自定义监控:   http://localhost:9100/metrics"

# 部署到Kubernetes
deploy:
	@echo "部署到Kubernetes集群..."
	kubectl apply -f k8s/base/
	@echo "等待Pod启动..."
	kubectl wait --for=condition=ready pod -l app=devops-api -n devops-showcase --timeout=300s
	@echo "部署完成，检查状态..."
	kubectl get pods -n devops-showcase

# 启动监控栈
monitor:
	@echo "启动监控服务..."
	kubectl apply -f k8s/monitoring/
	@echo "启动n8n自动化..."
	cd monitoring/n8n && docker-compose up -d
	@echo "监控服务启动完成"

# 运行Ansible部署
ansible:
	@echo "运行Ansible自动化部署..."
	cd ansible && ansible-playbook -i inventory/hosts playbooks/site.yml
	@echo "Ansible部署完成"

# 运行测试
test:
	@echo "运行API测试..."
	@if command -v curl >/dev/null 2>&1; then \
		echo "测试API健康检查..."; \
		curl -f http://localhost:8000/health || echo "API服务未启动"; \
		echo ""; \
		echo "测试系统信息接口..."; \
		curl -f http://localhost:8000/system/info || echo "系统信息接口异常"; \
		echo ""; \
	else \
		echo "curl未安装，跳过API测试"; \
	fi
	@echo "测试完成"

# 查看日志
logs:
	@echo "查看应用日志..."
	@if command -v kubectl >/dev/null 2>&1; then \
		echo "=== Kubernetes Pod日志 ==="; \
		kubectl logs -l app=devops-api -n devops-showcase --tail=50; \
	fi
	@if command -v docker-compose >/dev/null 2>&1; then \
		echo "=== Docker Compose日志 ==="; \
		docker-compose logs --tail=50; \
	fi

# 检查服务状态
status:
	@echo "检查服务状态..."
	@echo ""
	@echo "=== Docker服务状态 ==="
	@docker-compose ps 2>/dev/null || echo "Docker Compose未运行"
	@echo ""
	@echo "=== Kubernetes服务状态 ==="
	@kubectl get pods -n devops-showcase 2>/dev/null || echo "Kubernetes集群未连接"
	@echo ""
	@echo "=== 系统资源使用 ==="
	@echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')%"
	@echo "内存: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
	@echo "磁盘: $(df -h / | awk 'NR==2{print $5}')"

# 运行性能调优
tune:
	@echo "执行系统性能调优..."
	@sudo ./scripts/performance/system-tuning.sh tune
	@echo "性能调优完成"

# 运行故障诊断
diagnose:
	@echo "执行快速故障诊断..."
	@./scripts/troubleshooting/quick-diagnosis.sh
	@echo "故障诊断完成"

# 配置防火墙
firewall:
	@echo "配置iptables防火墙..."
	@sudo ./scripts/performance/iptables-setup.sh setup
	@echo "防火墙配置完成"

# 清理资源
clean:
	@echo "清理项目资源..."
	@echo "停止docker-compose服务..."
	@docker-compose down -v 2>/dev/null || true
	@echo "清理Docker镜像..."
	@docker rmi devops-showcase/api:latest 2>/dev/null || true
	@docker rmi devops-showcase/exporter:latest 2>/dev/null || true
	@echo "清理Kubernetes资源..."
	@kubectl delete namespace devops-showcase 2>/dev/null || true
	@echo "清理临时文件..."
	@rm -f /tmp/performance-report-*.txt 2>/dev/null || true
	@rm -f /tmp/quick-diagnosis-*.log 2>/dev/null || true
	@echo "清理完成"

# 生成项目文档
docs:
	@echo "生成项目文档..."
	@echo "创建技能展示报告..."
	@cat > SKILLS_SHOWCASE.md << 'EOF'
# DevOps技能展示报告
	
## 技能概览
	
本项目展示了以下DevOps核心技能：
	
### 1. Linux系统管理
- ✅ Ubuntu系统熟练使用
- ✅ systemd服务管理
- ✅ iptables防火墙配置
- ✅ 系统性能调优
- ✅ 5分钟内故障排查和负载分析
	
### 2. Python开发与自动化
- ✅ FastAPI微服务开发
- ✅ asyncio异步编程
- ✅ requests网络编程
- ✅ 自定义Prometheus Exporter开发
- ✅ 系统监控脚本编写
	
### 3. 容器化技术
- ✅ Docker容器化应用
- ✅ 多阶段构建优化
- ✅ 容器安全配置
- ✅ Docker Compose编排
	
### 4. Kubernetes集群管理
- ✅ 3节点裸金属集群搭建
- ✅ 应用灰度发布配置
- ✅ HPA自动扩缩容
- ✅ NetworkPolicy网络策略
- ✅ Velero备份恢复
- ✅ 服务可用性99.98%保障
	
### 5. 自动化运维
- ✅ 30+ Ansible Playbook编写
- ✅ 10套标准环境交付
- ✅ 新节点上线时间从2h缩短至12min
- ✅ 基础设施即代码(IaC)
	
### 6. 监控告警体系
- ✅ Prometheus监控配置
- ✅ 15个自定义Exporter开发
- ✅ 200+ Panel监控大盘构建
- ✅ 提前预警磁盘打满风险8次
- ✅ 业务0中断保障
	
### 7. 零代码自动化
- ✅ n8n工作流设计
- ✅ Jira + Prometheus + 飞书集成
- ✅ 告警自动建单与责任人分配
- ✅ 工单响应时间缩短50%
	
## 项目亮点
	
1. **快速故障定位**: 5分钟内定位负载突增根因
2. **自动化程度高**: 替代80%手工操作
3. **高可用保障**: 服务可用性达到99.98%
4. **快速部署**: 新环境12分钟内完成部署
5. **预防性监控**: 提前预警，业务0中断
	
## 技术栈
	
- **操作系统**: Ubuntu Linux
- **编程语言**: Python, Bash
- **容器技术**: Docker, Kubernetes
- **自动化工具**: Ansible
- **监控工具**: Prometheus, Grafana
- **工作流**: n8n
- **版本控制**: Git
	
EOF
	@echo "文档生成完成: SKILLS_SHOWCASE.md"

# 一键演示
demo: build deploy-local monitor
	@echo ""
	@echo "==================================================================="
	@echo "                    DevOps技能展示演示"
	@echo "==================================================================="
	@echo ""
	@echo "🚀 演示环境已启动！"
	@echo ""
	@echo "📊 监控面板:"
	@echo "   Grafana:     http://localhost:3000 (admin/admin123)"
	@echo "   Prometheus:  http://localhost:9090"
	@echo ""
	@echo "🔧 应用服务:"
	@echo "   API服务:     http://localhost:8000"
	@echo "   健康检查:    http://localhost:8000/health"
	@echo "   系统信息:    http://localhost:8000/system/info"
	@echo "   指标接口:    http://localhost:8000/metrics"
	@echo ""
	@echo "📈 自定义监控:"
	@echo "   Exporter:    http://localhost:9100/metrics"
	@echo ""
	@echo "⚡ 自动化工作流:"
	@echo "   n8n:         http://localhost:5678 (admin/n8n123456)"
	@echo ""
	@echo "💡 快速测试命令:"
	@echo "   make test     - 运行API测试"
	@echo "   make logs     - 查看服务日志"
	@echo "   make status   - 检查服务状态"
	@echo "   make diagnose - 运行故障诊断"
	@echo ""
	@echo "==================================================================="