# N8N 维护说明

## v0.1.0 - 2026-06-11

本仓库包含 n8n/监控/部署自动化相关脚本、Docker Compose、Kubernetes 与 Ansible 配置。本次维护以低风险发布基线为目标，不改动现有部署逻辑。

### 当前结构

- `monitoring/n8n/`：n8n compose 与 workflow。
- `monitoring/prometheus/`、`monitoring/grafana/`：监控配置与看板。
- `k8s/`：Kubernetes 基础资源与网络策略。
- `ansible/`：系统、Docker、K8s 与监控初始化 playbook。
- `scripts/`：性能调优与快速诊断 Shell 脚本。

### 本次维护

- 补充维护说明，明确仓库范围、风险边界与验证入口。
- 不直接改动部署脚本，避免在未知环境中破坏已有运行配置。
- 创建 v0.1.0 GitHub Release 作为后续继续维护的基线。

### 建议验证

```bash
bash -n scripts/performance/iptables-setup.sh
bash -n scripts/performance/system-tuning.sh
bash -n scripts/troubleshooting/quick-diagnosis.sh
docker compose config
```

> 注意：性能调优、iptables 与 Ansible/K8s 脚本可能影响宿主机或集群，请先在测试环境验证，不要直接在生产环境运行。
