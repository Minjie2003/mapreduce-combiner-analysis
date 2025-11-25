#!/bin/bash
# ============================================================================
# 脚本名称: run_experiments.sh
# 功能描述: 运行所有MapReduce实验并记录性能数据
# 实验设计:
#   - 3种数据集 (uniform, skewed, unique)
#   - 2种配置 (with/without Combiner)
#   - 共6个实验
# ============================================================================

# ----------------------------------------------------------------------------
# 1. 全局配置 - 根据当前用户调整
# ----------------------------------------------------------------------------
PROJECT_DIR=/export/data/code
BUILD_DIR=$PROJECT_DIR/build
RESULTS_DIR=$PROJECT_DIR/results

# 如果是 root 用户:
HDFS_INPUT_DIR=/user/root/input
HDFS_OUTPUT_DIR=/user/root/output

# 如果是 hadoop 用户（注释掉上面的，取消注释下面的）:
# HDFS_INPUT_DIR=/user/hadoop/input
# HDFS_OUTPUT_DIR=/user/hadoop/output

echo "=========================================="
echo "  MapReduce Combiner 性能对比实验"
echo "=========================================="
echo "当前用户: $(whoami)"
echo "项目目录: $PROJECT_DIR"
echo "HDFS输入: $HDFS_INPUT_DIR"
echo "HDFS输出: $HDFS_OUTPUT_DIR"
echo "结果目录: $RESULTS_DIR"
echo ""

# ----------------------------------------------------------------------------
# 2. 创建结果目录
# ----------------------------------------------------------------------------
echo "准备实验环境..."

# 创建本地结果目录（如果不存在）
if [ ! -d "$RESULTS_DIR" ]; then
    mkdir -p $RESULTS_DIR
    echo "✓ 创建结果目录: $RESULTS_DIR"
fi

# ----------------------------------------------------------------------------
# 3. 清理旧的HDFS输出
# ----------------------------------------------------------------------------
echo "清理旧的HDFS输出目录..."

# 删除所有旧的输出目录
# -r: 递归删除
# 2>/dev/null: 如果目录不存在，不显示错误
hdfs dfs -rm -r $HDFS_OUTPUT_DIR/* 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ 清理完成"
else
    echo "⚠️  警告: 清理可能失败（如果是首次运行可以忽略）"
fi

# ----------------------------------------------------------------------------
# 4. 验证JAR文件存在
# ----------------------------------------------------------------------------
echo ""
echo "检查JAR文件..."

WITHOUT_JAR=$BUILD_DIR/without-combiner/wordcount-without-combiner.jar
WITH_JAR=$BUILD_DIR/with-combiner/wordcount-with-combiner.jar

if [ ! -f "$WITHOUT_JAR" ]; then
    echo "✗ 错误: 找不到 $WITHOUT_JAR"
    echo "请先运行: ./compile_and_package.sh"
    exit 1
fi

if [ ! -f "$WITH_JAR" ]; then
    echo "✗ 错误: 找不到 $WITH_JAR"
    echo "请先运行: ./compile_and_package.sh"
    exit 1
fi

echo "✓ JAR文件检查通过"

# ----------------------------------------------------------------------------
# 5. 定义实验配置
# ----------------------------------------------------------------------------

# 数据集文件名数组
declare -a datasets=("uniform_data.txt" "skewed_data.txt" "unique_data.txt")

# 数据集简称数组（用于命名输出目录和日志文件）
declare -a dataset_names=("uniform" "skewed" "unique")

# 数据集描述（用于显示）
declare -a dataset_descriptions=(
    "均匀分布数据 - 词频相近"
    "数据倾斜 - 热点词占主导"
    "高唯一性 - 几乎无重复"
)

# ----------------------------------------------------------------------------
# 6. 运行实验循环
# ----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  开始实验 (共 6 个)"
echo "=========================================="

# 实验计数器
experiment_num=0
total_experiments=6

# 遍历每个数据集
for i in "${!datasets[@]}"; do
    # 获取当前数据集的各种信息
    dataset="${datasets[$i]}"              # 文件名: uniform_data.txt
    name="${dataset_names[$i]}"            # 简称: uniform
    description="${dataset_descriptions[$i]}"  # 描述

    echo ""
    echo "=========================================="
    echo "  数据集 $((i+1))/3: $dataset"
    echo "  说明: $description"
    echo "=========================================="

    # ------------------------------------------------------------------------
    # 实验A: 不带Combiner
    # ------------------------------------------------------------------------
    experiment_num=$((experiment_num + 1))
    echo ""
    echo ">>> 实验 $experiment_num/$total_experiments: ${name}_without_combiner"
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"

    # HDFS输出目录（每个实验独立的输出目录）
    output_dir="$HDFS_OUTPUT_DIR/${name}_without_combiner"

    # 本地日志文件
    log_file="$RESULTS_DIR/${name}_without_combiner.log"

    # 记录开始时间戳（秒）
    start_time=$(date +%s)

    # 运行MapReduce任务
    # hadoop jar: 运行JAR包中的MapReduce程序
    # 参数1: JAR文件路径
    # 参数2: 主类名（包含main方法）
    # 参数3: HDFS输入路径
    # 参数4: HDFS输出路径
    # > $log_file 2>&1: 将标准输出和错误输出都重定向到日志文件
    hadoop jar $WITHOUT_JAR \
        com.hadoop.wordcount.without.WordCountDriver \
        $HDFS_INPUT_DIR/$dataset \
        $output_dir \
        > $log_file 2>&1

    # 记录结束时间戳
    end_time=$(date +%s)

    # 计算执行时间（秒）
    duration=$((end_time - start_time))

    # 检查任务是否成功
    # $?: 上一个命令的退出状态码，0表示成功
    if [ $? -eq 0 ]; then
        echo "   ✓ 成功! 耗时: ${duration}秒"
        # 将执行时间追加到日志文件末尾，方便后续分析
        echo "EXECUTION_TIME=${duration}" >> $log_file
        echo "   日志: $log_file"
    else
        echo "   ✗ 失败! 查看日志: $log_file"
        echo "   常见原因:"
        echo "   1. HDFS输入文件不存在"
        echo "   2. 输出目录已存在"
        echo "   3. MapReduce配置问题"
    fi

    # 等待3秒，避免资源冲突
    sleep 3

    # ------------------------------------------------------------------------
    # 实验B: 带Combiner
    # ------------------------------------------------------------------------
    experiment_num=$((experiment_num + 1))
    echo ""
    echo ">>> 实验 $experiment_num/$total_experiments: ${name}_with_combiner"
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"

    output_dir="$HDFS_OUTPUT_DIR/${name}_with_combiner"
    log_file="$RESULTS_DIR/${name}_with_combiner.log"

    start_time=$(date +%s)

    hadoop jar $WITH_JAR \
        com.hadoop.wordcount.with.WordCountDriver \
        $HDFS_INPUT_DIR/$dataset \
        $output_dir \
        > $log_file 2>&1

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [ $? -eq 0 ]; then
        echo "   ✓ 成功! 耗时: ${duration}秒"
        echo "EXECUTION_TIME=${duration}" >> $log_file
        echo "   日志: $log_file"
    else
        echo "   ✗ 失败! 查看日志: $log_file"
    fi

    # 等待3秒
    sleep 3
done

# ----------------------------------------------------------------------------
# 7. 实验完成总结
# ----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  ✓ 所有实验完成!"
echo "=========================================="
echo ""
echo "实验结果汇总:"
echo "  总实验数: $total_experiments"
echo "  成功实验: $(ls $RESULTS_DIR/*.log 2>/dev/null | wc -l)"
echo ""
echo "日志文件位置: $RESULTS_DIR"
ls -lh $RESULTS_DIR/*.log 2>/dev/null

echo ""
echo "HDFS输出位置:"
hdfs dfs -ls $HDFS_OUTPUT_DIR/

echo ""
echo "=========================================="
echo "下一步操作:"
echo "  分析结果: ./analyze_results.sh"
echo "=========================================="