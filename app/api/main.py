import asyncio
import time
from typing import Dict, List
from fastapi import FastAPI, BackgroundTasks, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests
import psutil
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from fastapi.responses import Response

app = FastAPI(
    title="DevOps Showcase API",
    description="一个展示DevOps技能的FastAPI微服务",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prometheus指标
REQUEST_COUNT = Counter('api_requests_total', 'Total API requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('api_request_duration_seconds', 'Request duration')
SYSTEM_CPU_USAGE = Gauge('system_cpu_usage_percent', 'CPU usage percentage')
SYSTEM_MEMORY_USAGE = Gauge('system_memory_usage_percent', 'Memory usage percentage')
SYSTEM_DISK_USAGE = Gauge('system_disk_usage_percent', 'Disk usage percentage')

class HealthResponse(BaseModel):
    status: str
    timestamp: float
    version: str
    uptime: float

class SystemInfo(BaseModel):
    cpu_percent: float
    memory_percent: float
    disk_percent: float
    load_average: List[float]
    connections: int

class TaskRequest(BaseModel):
    task_type: str
    parameters: Dict

start_time = time.time()

@app.middleware("http")
async def metrics_middleware(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    
    REQUEST_COUNT.labels(method=request.method, endpoint=request.url.path).inc()
    REQUEST_DURATION.observe(process_time)
    
    return response

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """健康检查接口"""
    return HealthResponse(
        status="healthy",
        timestamp=time.time(),
        version="1.0.0",
        uptime=time.time() - start_time
    )

@app.get("/system/info", response_model=SystemInfo)
async def get_system_info():
    """获取系统信息"""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        load_avg = psutil.getloadavg() if hasattr(psutil, 'getloadavg') else [0.0, 0.0, 0.0]
        connections = len(psutil.net_connections())
        
        # 更新Prometheus指标
        SYSTEM_CPU_USAGE.set(cpu_percent)
        SYSTEM_MEMORY_USAGE.set(memory.percent)
        SYSTEM_DISK_USAGE.set(disk.percent)
        
        return SystemInfo(
            cpu_percent=cpu_percent,
            memory_percent=memory.percent,
            disk_percent=disk.percent,
            load_average=list(load_avg),
            connections=connections
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get system info: {str(e)}")

@app.post("/tasks/async")
async def create_async_task(task: TaskRequest, background_tasks: BackgroundTasks):
    """创建异步任务"""
    task_id = f"task_{int(time.time())}"
    
    async def process_task():
        print(f"Processing task {task_id}: {task.task_type}")
        await asyncio.sleep(2)  # 模拟任务处理
        print(f"Task {task_id} completed")
    
    background_tasks.add_task(process_task)
    
    return {
        "task_id": task_id,
        "status": "accepted",
        "task_type": task.task_type,
        "parameters": task.parameters
    }

@app.get("/external/ping")
async def ping_external_service():
    """使用requests库测试外部服务连接"""
    try:
        response = requests.get("https://httpbin.org/get", timeout=5)
        return {
            "status": "success",
            "response_code": response.status_code,
            "response_time": response.elapsed.total_seconds()
        }
    except requests.RequestException as e:
        raise HTTPException(status_code=503, detail=f"External service unavailable: {str(e)}")

@app.get("/async/demo")
async def async_demo():
    """演示异步编程能力"""
    async def fetch_data(url: str, delay: float):
        await asyncio.sleep(delay)
        return {"url": url, "data": f"Data from {url}", "delay": delay}
    
    # 并发执行多个异步任务
    tasks = [
        fetch_data("service-a", 0.5),
        fetch_data("service-b", 1.0),
        fetch_data("service-c", 0.3)
    ]
    
    start = time.time()
    results = await asyncio.gather(*tasks)
    end = time.time()
    
    return {
        "results": results,
        "total_time": end - start,
        "message": "异步执行，总时间小于各任务时间之和"
    }

@app.get("/metrics")
async def get_metrics():
    """Prometheus指标接口"""
    return Response(generate_latest(), media_type="text/plain")

@app.get("/load-test")
async def load_test_endpoint():
    """负载测试接口，模拟CPU密集型操作"""
    start = time.time()
    # 模拟CPU密集型操作
    total = sum(i * i for i in range(10000))
    end = time.time()
    
    return {
        "computation_result": total,
        "processing_time": end - start,
        "cpu_percent": psutil.cpu_percent()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)