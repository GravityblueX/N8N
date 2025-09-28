#!/usr/bin/env python3
"""
自定义Prometheus Exporter
监控系统性能指标，包括磁盘使用率预警等功能
"""

import time
import psutil
import subprocess
import os
from prometheus_client import start_http_server, Gauge, Counter, Info
from typing import Dict, List

class CustomExporter:
    def __init__(self, port: int = 9100):
        self.port = port
        
        # 系统指标
        self.cpu_usage = Gauge('custom_cpu_usage_percent', 'CPU使用率')
        self.memory_usage = Gauge('custom_memory_usage_percent', '内存使用率')
        self.disk_usage = Gauge('custom_disk_usage_percent', '磁盘使用率', ['mountpoint'])
        self.load_average = Gauge('custom_load_average', '系统负载', ['period'])
        
        # 网络指标
        self.network_bytes_sent = Counter('custom_network_bytes_sent_total', '网络发送字节数', ['interface'])
        self.network_bytes_recv = Counter('custom_network_bytes_recv_total', '网络接收字节数', ['interface'])
        self.network_connections = Gauge('custom_network_connections_total', '网络连接数', ['state'])
        
        # 进程指标
        self.process_count = Gauge('custom_process_count_total', '进程总数')
        self.zombie_processes = Gauge('custom_zombie_processes_total', '僵尸进程数')
        
        # 磁盘I/O指标
        self.disk_read_bytes = Counter('custom_disk_read_bytes_total', '磁盘读取字节数', ['device'])
        self.disk_write_bytes = Counter('custom_disk_write_bytes_total', '磁盘写入字节数', ['device'])
        self.disk_iops = Gauge('custom_disk_iops', '磁盘IOPS', ['device', 'operation'])
        
        # 自定义业务指标
        self.service_availability = Gauge('custom_service_availability', '服务可用性', ['service'])
        self.alert_threshold_exceeded = Counter('custom_alert_threshold_exceeded_total', '阈值告警次数', ['metric'])
        
        # 系统信息
        self.system_info = Info('custom_system_info', '系统信息')
        
        # 设置系统信息
        self._set_system_info()
    
    def _set_system_info(self):
        """设置系统基本信息"""
        try:
            import platform
            self.system_info.info({
                'hostname': platform.node(),
                'os': platform.system(),
                'os_version': platform.release(),
                'architecture': platform.machine(),
                'python_version': platform.python_version()
            })
        except Exception as e:
            print(f"Error setting system info: {e}")
    
    def collect_cpu_metrics(self):
        """收集CPU指标"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            self.cpu_usage.set(cpu_percent)
            
            # 负载平均值
            if hasattr(psutil, 'getloadavg'):
                load_avg = psutil.getloadavg()
                self.load_average.labels(period='1min').set(load_avg[0])
                self.load_average.labels(period='5min').set(load_avg[1])
                self.load_average.labels(period='15min').set(load_avg[2])
            
            # CPU负载过高告警
            if cpu_percent > 80:
                self.alert_threshold_exceeded.labels(metric='cpu_usage').inc()
                
        except Exception as e:
            print(f"Error collecting CPU metrics: {e}")
    
    def collect_memory_metrics(self):
        """收集内存指标"""
        try:
            memory = psutil.virtual_memory()
            self.memory_usage.set(memory.percent)
            
            # 内存使用率过高告警
            if memory.percent > 85:
                self.alert_threshold_exceeded.labels(metric='memory_usage').inc()
                
        except Exception as e:
            print(f"Error collecting memory metrics: {e}")
    
    def collect_disk_metrics(self):
        """收集磁盘指标"""
        try:
            # 磁盘使用率
            for partition in psutil.disk_partitions():
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    disk_percent = (usage.used / usage.total) * 100
                    self.disk_usage.labels(mountpoint=partition.mountpoint).set(disk_percent)
                    
                    # 磁盘空间预警（关键功能：提前预警磁盘打满风险）
                    if disk_percent > 90:
                        self.alert_threshold_exceeded.labels(metric='disk_usage').inc()
                        print(f"WARNING: Disk usage on {partition.mountpoint} is {disk_percent:.1f}%")
                    elif disk_percent > 85:
                        print(f"NOTICE: Disk usage on {partition.mountpoint} is {disk_percent:.1f}%")
                        
                except PermissionError:
                    continue
            
            # 磁盘I/O
            disk_io = psutil.disk_io_counters(perdisk=True)
            for device, io_counters in disk_io.items():
                self.disk_read_bytes.labels(device=device)._value._value = io_counters.read_bytes
                self.disk_write_bytes.labels(device=device)._value._value = io_counters.write_bytes
                
        except Exception as e:
            print(f"Error collecting disk metrics: {e}")
    
    def collect_network_metrics(self):
        """收集网络指标"""
        try:
            # 网络I/O
            net_io = psutil.net_io_counters(pernic=True)
            for interface, io_counters in net_io.items():
                self.network_bytes_sent.labels(interface=interface)._value._value = io_counters.bytes_sent
                self.network_bytes_recv.labels(interface=interface)._value._value = io_counters.bytes_recv
            
            # 网络连接状态
            connections = psutil.net_connections()
            connection_states = {}
            for conn in connections:
                state = conn.status
                connection_states[state] = connection_states.get(state, 0) + 1
            
            for state, count in connection_states.items():
                self.network_connections.labels(state=state).set(count)
                
        except Exception as e:
            print(f"Error collecting network metrics: {e}")
    
    def collect_process_metrics(self):
        """收集进程指标"""
        try:
            processes = list(psutil.process_iter(['pid', 'name', 'status']))
            self.process_count.set(len(processes))
            
            # 统计僵尸进程
            zombie_count = sum(1 for p in processes if p.info['status'] == psutil.STATUS_ZOMBIE)
            self.zombie_processes.set(zombie_count)
            
        except Exception as e:
            print(f"Error collecting process metrics: {e}")
    
    def check_service_availability(self):
        """检查服务可用性"""
        services = {
            'ssh': 22,
            'http': 80,
            'https': 443,
            'prometheus': 9090,
            'grafana': 3000
        }
        
        for service, port in services.items():
            try:
                import socket
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(1)
                result = sock.connect_ex(('localhost', port))
                sock.close()
                
                availability = 1 if result == 0 else 0
                self.service_availability.labels(service=service).set(availability)
                
            except Exception as e:
                self.service_availability.labels(service=service).set(0)
                print(f"Error checking {service} availability: {e}")
    
    def collect_all_metrics(self):
        """收集所有指标"""
        print(f"Collecting metrics at {time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        self.collect_cpu_metrics()
        self.collect_memory_metrics()
        self.collect_disk_metrics()
        self.collect_network_metrics()
        self.collect_process_metrics()
        self.check_service_availability()
    
    def start_server(self):
        """启动HTTP服务器"""
        start_http_server(self.port)
        print(f"Custom Exporter started on port {self.port}")
        print(f"Metrics available at http://localhost:{self.port}/metrics")
        
        try:
            while True:
                self.collect_all_metrics()
                time.sleep(30)  # 每30秒收集一次指标
        except KeyboardInterrupt:
            print("Custom Exporter stopped")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Custom Prometheus Exporter')
    parser.add_argument('--port', type=int, default=9100, help='Port to run the exporter on')
    args = parser.parse_args()
    
    exporter = CustomExporter(port=args.port)
    exporter.start_server()