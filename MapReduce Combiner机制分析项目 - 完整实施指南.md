# MapReduce Combiner机制分析项目 - 完整实施指南

我会给你一个**超详细的、可直接执行**的完整指南。

------

## 📋 项目总览

**目标**: 通过实验验证Combiner在不同数据分布下对MapReduce性能的影响

**时间**: 28天

**交付物**:

- 可运行的代码
- 完整的实验数据
- 详细的分析报告

------

# 🗓️ Week 1: 环境搭建 + 理论准备

## Day 1-2: Docker环境搭建

### Step 1: 安装Docker Desktop

**Windows用户：**

bash

```bash
# 1. 下载Docker Desktop
# 访问: https://www.docker.com/products/docker-desktop/

# 2. 安装并重启电脑

# 3. 验证安装
docker --version
docker-compose --version
```

**配置Docker资源：**

- 打开Docker Desktop
- Settings → Resources
- Memory: 至少 8GB
- CPUs: 至少 4核
- Disk: 至少 50GB

### Step 2: 创建项目结构

bash

```bash
# 创建项目根目录
mkdir mapreduce-combiner-analysis
cd mapreduce-combiner-analysis

# 创建子目录
mkdir -p code/mapreduce/with-combiner
mkdir -p code/mapreduce/without-combiner
mkdir -p code/data-generator
mkdir -p code/scripts
mkdir -p code/utils
mkdir -p docs/images
mkdir -p results/raw-data
mkdir -p results/charts
mkdir -p cluster-config
```

### Step 3: 创建Docker配置

**创建 `cluster-config/docker-compose.yml`:**

docker-compose.yml

Code 

version: '3.8' services:  namenode:    image: bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8    container_name: namenode    restart: always    ports:      - 9870:9870  # NameNode Web UI      - 9000:9000  # HDFS端口    volumes:      - hadoop_

**创建 `cluster-config/hadoop.env`:**

hadoop.env

Code 

\# Core配置 CORE_CONF_fs_defaultFS=hdfs://namenode:9000 CORE_CONF_hadoop_http_staticuser_user=root CORE_CONF_hadoop_proxyuser_hue_hosts=* CORE_CONF_hadoop_proxyuser_hue_groups=* CORE_CONF_io_compression_codecs=org.apache.hadoop.io.compress.SnappyCodec

### Step 4: 启动集群

bash

```bash
# 进入配置目录
cd cluster-config

# 创建共享目录
mkdir shared

# 启动集群（首次启动会下载镜像，需要5-10分钟）
docker-compose up -d

# 查看启动状态
docker-compose ps

# 查看日志（确保没有错误）
docker-compose logs -f

# 等待所有服务启动（约2-3分钟）
```

### Step 5: 验证集群

**1. 检查Web界面：**

- NameNode: http://localhost:9870
- YARN: http://localhost:8088
- JobHistory: http://localhost:8188

**截图要求：**

- 打开NameNode界面，截图显示"Live Nodes: 3"
- 打开YARN界面，截图显示ResourceManager运行正常
- 确保截图中包含你的电脑用户名或时间戳

**2. 测试HDFS：**

bash

```bash
# 进入namenode容器
docker exec -it namenode bash

# 查看HDFS状态
hdfs dfsadmin -report

# 应该看到3个DataNode，每个状态为Live

# 创建测试目录
hdfs dfs -mkdir -p /user/root/test

# 测试文件上传
echo "Hello Hadoop Cluster" > /tmp/test.txt
hdfs dfs -put /tmp/test.txt /user/root/test/

# 查看文件
hdfs dfs -ls /user/root/test/
hdfs dfs -cat /user/root/test/test.txt

# 退出容器
exit
```

**截图：**

- `hdfs dfsadmin -report` 的输出
- `hdfs dfs -ls` 的输出

------

## Day 3: 运行WordCount验证

### Step 1: 准备测试数据

bash

```bash
docker exec -it namenode bash

# 创建输入数据
cat > /tmp/input.txt << EOF
hello world hello hadoop
hello docker hello mapreduce
hadoop mapreduce yarn hdfs
combiner reducer mapper shuffle
data processing big data
EOF

# 上传到HDFS
hdfs dfs -mkdir -p /input
hdfs dfs -put /tmp/input.txt /input/
hdfs dfs -ls /input/
```

### Step 2: 运行自带WordCount

bash

~~~bash
# 运行WordCount示例
hadoop jar /opt/hadoop-3.2.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar \
  wordcount /input /output

# 查看结果
hdfs dfs -cat /output/part-r-00000
```

**预期输出：**
```
big     1
combiner        1
data    2
docker  1
hadoop  2
...
~~~

### Step 3: 在YARN查看作业

1. 访问 http://localhost:8088

2. 点击 "Applications" → 找到刚才的WordCount作业

3. 点击 "ApplicationMaster" → 查看作业详情

4. 截图保存

   ：

   - 作业完成状态
   - 执行时间
   - Map/Reduce任务数量

### Step 4: 查看作业日志

bash

```bash
# 查看作业历史
yarn application -list -appStates ALL

# 获取Application ID (格式: application_xxxxxxxxxx_xxxx)
# 查看日志
yarn logs -applicationId <Application_ID>
```

**退出容器：**

bash

```bash
exit
```

------

## Day 4: 编写环境文档

创建 `docs/setup-guide.md`，记录：

1. 集群配置信息

   ：

   - 节点数量：1 NameNode + 3 DataNode
   - 资源配置：CPU、内存、磁盘
   - Hadoop版本：3.2.1
   - JDK版本：8

2. 部署步骤

   ：

   - Docker安装过程
   - 配置文件说明
   - 启动命令

3. 验证截图

   ：

   - 插入所有之前的截图
   - 添加说明文字

4. **常用命令速查**：

bash

```bash
   # 启动集群
   docker-compose up -d
   
   # 停止集群
   docker-compose down
   
   # 查看日志
   docker-compose logs [service_name]
   
   # 进入容器
   docker exec -it namenode bash
   
   # HDFS命令
   hdfs dfs -ls /
   hdfs dfs -put local_file hdfs_path
   hdfs dfs -get hdfs_path local_file
```

------

## Day 5-7: 理论学习 + 实验设计

### Combiner机制研究（成员C+D负责）

**任务：**

1. 阅读Hadoop官方文档关于Combiner的部分
2. 理解Combiner的工作原理
3. 分析Combiner的适用场景

**输出文档 `docs/combiner-theory.md`：**

markdown

```markdown
# Combiner机制原理

## 1. 什么是Combiner？
Combiner是运行在Map端的"本地Reducer"，在数据发送到Reduce之前进行预聚合。

## 2. 工作流程
Map → Combiner → Shuffle → Reducer

## 3. 优势
- 减少网络传输数据量
- 降低Reducer负载
- 提升整体性能

## 4. 限制条件
- 必须满足结合律和交换律
- 例如：求和✓、求平均值✗

## 5. 适用场景
- WordCount
- 求和、计数
- 找最大/最小值

## 6. 不适用场景
- 求平均值
- 求中位数
- 需要全局视图的计算
```

### 实验方案设计

**创建 `docs/experiment-design.md`：**

实验设计方案

Document 

\# MapReduce Combiner机制分析 - 实验设计方案 ## 1. 研究问题 ### 核心问题 1. Combiner能否有效减少Shuffle阶段的数据量？ 2. 在不同key分布下，Combiner的性能提升效果有何差异？ 3. 是否所有场景都适合使用Combiner？ ### 假设 - H1: Combiner能显著减少Shuffle数据量（预期减少50%+） - H2: 数据倾斜越严重，Combiner效果越不明显 - H3: 某些计算场景不适合使用Combiner

------

# 🗓️ Week 2: 代码开发

## Day 8-10: 数据生成器开发

### Step 1: 创建数据生成器

**创建 `code/data-generator/DataGenerator.java`:**

DataGenerator.java

Code 

import java.io.*; import java.util.*; /** * 数据生成器 - 生成不同分布的WordCount测试数据 */ public class DataGenerator {        private static final String[] WORDS = {        "hadoop", "mapreduce", "combiner", "reducer", "mapper",         "shuffle", "partitio

### Step 2: 编译和测试数据生成器

bash

```bash
# 编译
cd code/data-generator
javac DataGenerator.java

# 生成测试数据（先生成小数据测试）
java DataGenerator uniform test_uniform_10mb.txt 10
java DataGenerator skewed test_skewed_10mb_light.txt 10 0.5
java DataGenerator skewed test_skewed_10mb_heavy.txt 10 2.0

# 查看生成的文件
ls -lh *.txt
```

### Step 3: 生成完整实验数据集

**创建生成脚本 `code/data-generator/generate_all.sh`:**

bash

```bash
#!/bin/bash

echo "开始生成所有数据集..."

# 创建输出目录
mkdir -p ../../datasets

# 均匀分布数据集
echo "=== 生成均匀分布数据集 ==="
java DataGenerator uniform ../../datasets/uniform_100mb.txt 100
java DataGenerator uniform ../../datasets/uniform_500mb.txt 500
java DataGenerator uniform ../../datasets/uniform_1gb.txt 1000

# 倾斜分布数据集
echo "=== 生成倾斜分布数据集 ==="
# 轻度倾斜 (alpha=0.5)
java DataGenerator skewed ../../datasets/skewed_light_100mb.txt 100 0.5
java DataGenerator skewed ../../datasets/skewed_light_500mb.txt 500 0.5

# 中度倾斜 (alpha=1.0)
java DataGenerator skewed ../../datasets/skewed_medium_100mb.txt 100 1.0
java DataGenerator skewed ../../datasets/skewed_medium_500mb.txt 500 1.0

# 重度倾斜 (alpha=2.0)
java DataGenerator skewed ../../datasets/skewed_heavy_100mb.txt 100 2.0
java DataGenerator skewed ../../datasets/skewed_heavy_500mb.txt 500 2.0

echo "所有数据集生成完成!"
ls -lh ../../datasets/
```

bash

```bash
# 给脚本执行权限
chmod +x generate_all.sh

# 运行（这会需要一些时间）
./generate_all.sh
```

------

## Day 11-13: MapReduce作业开发

### Step 1: 不带Combiner的WordCount

**创建 `code/mapreduce/without-combiner/WordCountNoCombiner.java`:**

WordCountNoCombiner.java

Code 

import org.apache.hadoop.conf.Configuration; import org.apache.hadoop.fs.Path; import org.apache.hadoop.io.IntWritable; import org.apache.hadoop.io.LongWritable; import org.apache.hadoop.io.Text; import org.apache.hadoop.mapreduce.Job; import org.apa

### Step 2: 带Combiner的WordCount

**创建 `code/mapreduce/with-combiner/WordCountWithCombiner.java`:**

WordCountWithCombiner.java

Code 

import org.apache.hadoop.conf.Configuration; import org.apache.hadoop.fs.Path; import org.apache.hadoop.io.IntWritable; import org.apache.hadoop.io.LongWritable; import org.apache.hadoop.io.Text; import org.apache.hadoop.mapreduce.Job; import org.apa

### Step 3: 编译MapReduce作业

**创建编译脚本 `code/scripts/compile.sh`:**

bash

```bash
#!/bin/bash

echo "开始编译MapReduce作业..."

# 设置Hadoop classpath
HADOOP_CLASSPATH=$(docker exec namenode hadoop classpath)

# 创建输出目录
mkdir -p ../build

# 编译不带Combiner的版本
echo "编译 WordCountNoCombiner..."
javac -classpath "$HADOOP_CLASSPATH" \
    -d ../build \
    ../mapreduce/without-combiner/WordCountNoCombiner.java

# 打包
cd ../build
jar -cvf WordCountNoCombiner.jar *.class
cd ../scripts

# 编译带Combiner的版本
echo "编译 WordCountWithCombiner..."
javac -classpath "$HADOOP_CLASSPATH" \
    -d ../build \
    ../mapreduce/with-combiner/WordCountWithCombiner.java

# 打包
cd ../build
jar -cvf WordCountWithCombiner.jar *.class
cd ../scripts

echo "编译完成!"
ls -lh ../build/*.jar
```

**Windows上的替代方案 - 在Docker容器内编译：**

bash

```bash
# 1. 将代码复制到共享目录
cp -r code/mapreduce cluster-config/shared/

# 2. 进入namenode容器编译
docker exec -it namenode bash

# 3. 在容器内编译
cd /shared/mapreduce

# 编译不带Combiner版本
javac -classpath $(hadoop classpath) without-combiner/WordCountNoCombiner.java
cd without-combiner
jar -cvf WordCountNoCombiner.jar *.class
cd ..

# 编译带Combiner版本
javac -classpath $(hadoop classpath) with-combiner/WordCountWithCombiner.java
cd with-combiner
jar -cvf WordCountWithCombiner.jar *.class
cd ..

exit
```

------

## Day 14: 自动化测试脚本

**创建 `code/scripts/run_experiment.sh`:**

run_experiment.sh

Code 

\#!/bin/bash # 实验自动化脚本 # 用法: ./run_experiment.sh <dataset_name> <use_combiner> <run_number> if [ $# -ne 3 ]; then    echo "用法: $0 <dataset_name> <use_combiner:yes|no> <run_number>"    echo "示例: $0 uniform_100mb yes 1"    exit 1 fi DATASET=$1 USE

------

# 🗓️ Week 3: 实验执行

## Day 15-20: 批量运行实验

### Step 1: 创建批量实验脚本

**创建 `code/scripts/run_all_experiments.sh`:**

bash

```bash
#!/bin/bash

# 批量运行所有实验组合
# 每组实验运行3次取平均

echo "开始批量实验..."
echo "预计总时间: 约2-3小时"

# 数据集列表
DATASETS=(
    "uniform_100mb"
    "uniform_500mb"
    "skewed_light_100mb"
    "skewed_light_500mb"
    "skewed_medium_100mb"
    "skewed_medium_500mb"
    "skewed_heavy_100mb"
    "skewed_heavy_500mb"
)

# 对每个数据集运行实验
for dataset in "${DATASETS[@]}"; do
    echo ""
    echo "================================================"
    echo "测试数据集: $dataset"
    echo "================================================"
    
    # 运行3次不带Combiner的实验
    for run in 1 2 3; do
        echo "运行: 不带Combiner - 第${run}次"
        ./run_experiment.sh $dataset no $run
        sleep 30  # 等待集群稳定
    done
    
    # 运行3次带Combiner的实验
    for run in 1 2 3; do
        echo "运行: 带Combiner - 第${run}次"
        ./run_experiment.sh $dataset yes $run
        sleep 30
    done
    
    echo "数据集 $dataset 完成"
done

echo ""
echo "================================================"
echo "所有实验完成!"
echo "================================================"
echo "开始汇总结果..."

# 生成汇总报告
python3 ../utils/summarize_results.py
```

bash

```bash
# 给脚本执行权限
chmod +x run_experiment.sh
chmod +x run_all_experiments.sh
```

### Step 2: 创建结果汇总脚本

**创建 `code/utils/summarize_results.py`:**

summarize_results.py

Code 

\#!/usr/bin/env python3 """ 实验结果汇总脚本 解析所有实验日志，生成CSV格式的汇总数据 """ import os import re import csv from collections import defaultdict import statistics def parse_result_file(filepath):    """解析单个结果文件，提取关键指标"""    metrics = {}        with open(filepa

### Step 3: 开始实验（分工执行）

**执行计划：**

1. **Day 15-16**：运行小规模数据集（100MB）

bash

```bash
   # 测试单个实验
   cd code/scripts
   ./run_experiment.sh uniform_100mb no 1
   ./run_experiment.sh uniform_100mb yes 1
   
   # 检查结果
   cat ../../results/raw-data/uniform_100mb_without_combiner_run1.txt
```

1. **Day 17-18**：运行中规模数据集（500MB）

bash

```bash
   # 可以并行运行多个数据集
   ./run_experiment.sh uniform_500mb no 1 &
   ./run_experiment.sh skewed_light_500mb no 1 &
   wait
```

1. Day 19-20

   ：补充实验 + 异常处理

   - 重跑失败的实验
   - 验证数据完整性
   - 生成初步汇总

------

# 🗓️ Week 4: 数据分析与报告

## Day 21-23: 数据可视化

### Step 1: 创建可视化脚本

**创建 `code/utils/visualize_results.py`:**

visualize_results.py

Code 

\#!/usr/bin/env python3 """ 实验结果可视化脚本 生成论文质量的图表 """ import pandas as pd import matplotlib.pyplot as plt import seaborn as sns import numpy as np import os # 设置中文字体和样式 plt.rcParams['font.sans-serif'] = ['SimHei', 'Arial Unicode MS', 'DejaVu Sans'] pl

### Step 2: 运行可视化

bash

```bash
# 安装依赖
pip3 install pandas matplotlib seaborn numpy

# 生成图表
cd code/utils
python3 visualize_results.py
```

------

## Day 24-27: 撰写报告

### 最终README.md结构

按照老师要求的模板填写：

README.md（完整版）

Document 

\# MapReduce Combiner机制分析 ## 研究目的 探究MapReduce中Combiner对作业性能的影响，为分布式计算场景下的性能优化提供实践依据。 ## 研究内容 分析Combiner在MapReduce执行过程中的作用与效果。具体包括： 1. Combiner是否能够有效减少Shuffle阶段的数据量？ 2. 在不同的key分布（均匀分布与数据倾斜）下，其性能提升效果有何差异？ 3. 是否所有场景都适合使用Combiner？ **【新增研究内容】** 4. 不同数据规

------

## Day 28: 最终检查与提交

### 检查清单

bash

```bash
# 1. 确保所有代码可运行
cd code/mapreduce/with-combiner
jar -tf WordCountWithCombiner.jar

# 2. 验证所有数据文件存在
ls -lh datasets/
ls -lh results/raw-data/
ls -lh results/charts/

# 3. 检查文档完整性
- [ ] README.md 完整
- [ ] docs/setup-guide.md
- [ ] docs/experiment-design.md
- [ ] 所有截图已插入

# 4. Git提交
git add .
git commit -m "feat: 完成MapReduce Combiner机制分析项目"
git push origin main
```

------

## 💡 关键Tips

### Git协作最佳实践

bash

```bash
# 第一次克隆
git clone <your-repo-url>
cd mapreduce-combiner-analysis

# 创建功能分支
git checkout -b feature/your-name-your-task

# 提交你的工作
git add .
git commit -m "feat: 完成XXX功能"
git push origin feature/your-name-your-task

# 创建Pull Request在GitHub上
# 其他成员审查后合并
```

### 常见问题解决

**Q1: Docker容器无法启动**

bash

```bash
# 检查端口占用
netstat -ano | findstr 9870

# 重启Docker
docker-compose down
docker-compose up -d
```

**Q2: Hadoop作业失败**

bash

```bash
# 查看详细日志
docker exec namenode bash
yarn logs -applicationId <app_id>

# 检查HDFS空间
hdfs dfs -df -h
```

**Q3: 数据倾斜不明显**

bash

```bash
# 增大alpha参数
java DataGenerator skewed test.txt 100 3.0

# 验证分布
python3 -c "
import collections
words = open('test.txt').read().split()
c = collections.Counter(words)
print('Top 10:', c.most_common(10))
"
```

------

## 📚 参考资料

1. Hadoop官方文档: https://hadoop.apache.org/docs/r3.2.1/
2. MapReduce论文: Dean, Jeffrey, and Sanjay Ghemawat. "MapReduce: simplified data processing on large clusters."
3. Docker文档: https://docs.docker.com/

------

## 🎯 总结

这个28天的详细计划涵盖了：

1. ✅ 环境搭建（Docker集群）
2. ✅ 数据生成（8个不同分布的数据集）
3. ✅ 代码开发（带/不带Combiner两个版本）
4. ✅ 自动化实验（批量执行脚本）
5. ✅ 数据分析（统计脚本）
6. ✅ 可视化（5张专业图表）
7. ✅ 完整报告（符合模板要求）