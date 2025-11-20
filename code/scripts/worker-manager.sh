#!/bin/bash
# Hadoop Worker 管理脚本

set -e

ACTION=${1:-help}

case "$ACTION" in
  start)
    echo "[INFO] 启动DataNode和NodeManager..."
    docker-compose -f ../docker-compose-worker.yml up -d
    ;;
  stop)
    echo "[INFO] 停止DataNode和NodeManager..."
    docker-compose -f ../docker-compose-worker.yml down
    ;;
  status)
    echo "[INFO] 查看Worker容器状态..."
    docker-compose -f ../docker-compose-worker.yml ps
    ;;
  logs)
    SERVICE=$2
    docker-compose -f ../docker-compose-worker.yml logs --tail=50 -f "$SERVICE"
    ;;
  help|--help)
    echo "用法: ./worker-manager.sh [start|stop|status|logs <service>]"
    ;;
  *)
    echo "[ERROR] 未知命令: $ACTION"
    ;;
esac
