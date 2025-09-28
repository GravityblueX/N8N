# 贡献指南

感谢你对DevOps技能展示项目的关注！我们欢迎所有形式的贡献。

## 🤝 如何贡献

### 报告Bug
如果你发现了bug，请在GitHub Issues中创建一个issue，包含以下信息：
- 详细的问题描述
- 复现步骤
- 期望的行为
- 实际的行为
- 系统环境信息

### 功能建议
如果你有新功能的想法，请：
1. 在Issues中搜索是否已有类似建议
2. 创建新的Feature Request issue
3. 详细描述功能需求和使用场景

### 代码贡献
1. Fork项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

## 📝 代码规范

### Python代码规范
- 遵循PEP 8规范
- 使用black进行代码格式化
- 使用类型注解
- 编写docstring文档

### Shell脚本规范
- 使用`#!/bin/bash`
- 使用`set -euo pipefail`
- 添加适当的注释
- 使用函数组织代码

### YAML配置规范
- 使用2个空格缩进
- 保持一致的键值对格式
- 添加必要的注释

## 🧪 测试

在提交代码前，请确保：
- 所有测试通过
- 新功能有相应的测试
- 文档已更新

```bash
# 运行测试
make test

# 检查代码格式
black --check .
flake8 .
```

## 📚 文档

- 更新相关的README文档
- 添加新功能的使用说明
- 更新DEPLOYMENT.md部署指南

## 🏷️ 提交规范

使用清晰的提交信息：
```
类型: 简短描述

详细描述（可选）

相关Issue: #123
```

类型包括：
- `feat`: 新功能
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建工具等

## 📄 许可证

通过贡献代码，你同意你的贡献将在MIT许可证下发布。