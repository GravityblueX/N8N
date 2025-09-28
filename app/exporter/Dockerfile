FROM python:3.11-slim

LABEL maintainer="DevOps Engineer"
LABEL description="自定义Prometheus Exporter容器镜像"

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 安装Python依赖
RUN pip install --no-cache-dir prometheus-client psutil

# 复制exporter代码
COPY custom_exporter.py .

# 创建非root用户
RUN useradd -m -u 1000 exporter && chown -R exporter:exporter /app
USER exporter

# 暴露端口
EXPOSE 9100

# 健康检查
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9100/metrics || exit 1

# 启动命令
CMD ["python", "custom_exporter.py", "--port", "9100"]