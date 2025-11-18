#!/bin/bash

# 分布式Hadoop集群管理脚本（主节点）

set -e

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CODE_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# 启动主节点
start_master() {
    print_header "启动主节点服务"
    print_msg "启动 NameNode, ResourceManager, HistoryServer..."
    docker-compose -f docker-compose-master.yml up -d

    print_msg "等待服务启动..."
    sleep 20

    print_msg "主节点服务状态:"
    docker-compose -f docker-compose-master.yml ps

    print_msg "\n主节点访问地址:"
    echo "  NameNode Web UI:        http://localhost:9870"
    echo "  ResourceManager Web UI: http://localhost:8088"
    echo "  HistoryServer Web UI:   http://localhost:8188"

    print_warning "\n✅ 主节点启动完成！请通知组员启动工作节点。"
}

# 停止主节点
stop_master() {
    print_header "停止主节点服务"
    docker-compose -f docker-compose-master.yml down
    print_msg "主节点已停止"
}

# 查看集群状态
status_cluster() {
    print_header "Hadoop分布式集群状态"

    echo ""
    print_msg "1. 主节点容器状态:"
    docker-compose -f docker-compose-master.yml ps

    echo ""
    print_msg "2. HDFS DataNode 状态:"
    docker exec namenode hdfs dfsadmin -report | grep -A 5 "Live datanodes" || echo "暂无DataNode连接"

    echo ""
    print_msg "3. YARN NodeManager 状态:"
    docker exec resourcemanager yarn node -list || echo "暂无NodeManager连接"

    echo ""
    print_msg "4. 集群健康检查:"
    docker exec namenode hdfs dfsadmin -report | head -n 20
}

# 查看所有DataNode
list_datanodes() {
    print_header "DataNode 列表"
    docker exec namenode hdfs dfsadmin -report | grep "Name:" -A 2
}

# 查看所有NodeManager
list_nodemanagers() {
    print_header "NodeManager 列表"
    docker exec resourcemanager yarn node -list -all
}

# 初始化HDFS
init_hdfs() {
    print_header "初始化HDFS目录"

    docker exec namenode hdfs dfs -mkdir -p /user/root
    docker exec namenode hdfs dfs -mkdir -p /input
    docker exec namenode hdfs dfs -mkdir -p /output
    docker exec namenode hdfs dfs -mkdir -p /data
    docker exec namenode hdfs dfs -mkdir -p /tmp

    docker exec namenode hdfs dfs -chmod -R 777 /user
    docker exec namenode hdfs dfs -chmod -R 777 /input
    docker exec namenode hdfs dfs -chmod -R 777 /output
    docker exec namenode hdfs dfs -chmod -R 777 /data
    docker exec namenode hdfs dfs -chmod -R 777 /tmp

    print_msg "HDFS目录初始化完成"
    docker exec namenode hdfs dfs -ls /
}

# 测试集群
test_cluster() {
    print_header "集群功能测试"

    print_msg "1. 测试HDFS写入..."
    docker exec namenode bash -c "
        echo 'Hadoop Distributed Cluster Test' > /tmp/test.txt
        hdfs dfs -put -f /tmp/test.txt /test.txt
        hdfs dfs -cat /test.txt
    "

    echo ""
    print_msg "2. 运行MapReduce示例（计算PI）..."
    docker exec namenode hadoop jar \
        /opt/hadoop-3.2.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar \
        pi 2 100

    echo ""
    print_msg "✅ 测试完成！集群运行正常。"
}

# 查看日志
logs_master() {
    local service=$1
    if [ -z "$service" ]; then
        print_msg "查看所有主节点服务日志..."
        docker-compose -f docker-compose-master.yml logs --tail=50 -f
    else
        print_msg "查看 $service 日志..."
        docker-compose -f docker-compose-master.yml logs --tail=50 -f "$service"
    fi
}

# 进入容器
shell_master() {
    local service=${1:-namenode}
    print_msg "进入 $service 容器..."
    print_msg "代码目录: /opt/code"
    docker exec -it "$service" /bin/bash
}

# 显示组员部署指南
show_worker_guide() {
    print_header "📋 组员工作节点部署指南"

    # 尝试获取本机IP
    LOCAL_IP=$(ipconfig 2>/dev/null | grep "IPv4" | head -1 | awk '{print $NF}' | tr -d '\r')

    cat << EOF

请将以下信息发送给组员：

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 主节点信息
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
主节点IP: ${LOCAL_IP:-[请手动通过ipconfig查看]}

需要访问的地址：
- NameNode:        http://${LOCAL_IP:-[主节点IP]}:9870
- ResourceManager: http://${LOCAL_IP:-[主节点IP]}:8088

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 部署步骤（组员执行）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣ 安装环境
   - Docker Desktop
   - WSL2

2️⃣ 创建配置文件
   创建目录: mkdir hadoop-worker && cd hadoop-worker
   创建文件: docker-compose-worker.yml 和 hadoop-worker.env
   (详细内容见《工作节点部署笔记》)

3️⃣ 修改IP地址
   将配置文件中的 192.168.1.100 替换为: ${LOCAL_IP:-[主节点IP]}

4️⃣ 开放防火墙端口
   端口: 9864, 9866, 9867, 8042

5️⃣ 启动工作节点
   docker-compose -f docker-compose-worker.yml up -d

6️⃣ 验证连接
   访问主节点Web界面查看DataNode和NodeManager是否出现

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
}

# 帮助信息
show_help() {
    cat << EOF
分布式Hadoop集群管理脚本（主节点）

用法: ./scripts/cluster-manager.sh [命令]

命令:
  start           启动主节点服务
  stop            停止主节点服务
  status          查看集群状态
  datanodes       查看所有DataNode
  nodemanagers    查看所有NodeManager
  init            初始化HDFS目录
  test            测试集群功能
  logs [service]  查看日志
  shell [service] 进入容器
  worker-guide    显示组员部署指南
  help            显示此帮助

示例:
  ./scripts/cluster-manager.sh start         # 启动主节点
  ./scripts/cluster-manager.sh status        # 查看集群状态
  ./scripts/cluster-manager.sh datanodes     # 查看所有数据节点
  ./scripts/cluster-manager.sh worker-guide  # 获取组员部署指南

EOF
}

# 主函数
main() {
    case "${1:-help}" in
        start)
            start_master
            ;;
        stop)
            stop_master
            ;;
        status)
            status_cluster
            ;;
        datanodes)
            list_datanodes
            ;;
        nodemanagers)
            list_nodemanagers
            ;;
        init)
            init_hdfs
            ;;
        test)
            test_cluster
            ;;
        logs)
            logs_master "$2"
            ;;
        shell)
            shell_master "$2"
            ;;
        worker-guide)
            show_worker_guide
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"