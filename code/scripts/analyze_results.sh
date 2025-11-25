#!/bin/bash
# ============================================================================
# 脚本名称: analyze_results.sh
# 功能描述: 分析MapReduce实验结果，生成性能对比报告
# 输入: results/*.log 日志文件
# 输出: performance_metrics.csv + 控制台分析报告
# ============================================================================

# ----------------------------------------------------------------------------
# 1. 全局配置
# ----------------------------------------------------------------------------
PROJECT_DIR=/export/data/code
RESULTS_DIR=$PROJECT_DIR/results

echo "=========================================="
echo "  MapReduce Combiner 实验结果分析"
echo "=========================================="
echo "结果目录: $RESULTS_DIR"
echo ""

# ----------------------------------------------------------------------------
# 2. 检查日志文件是否存在
# ----------------------------------------------------------------------------
echo "检查实验日志文件..."

if [ ! -d "$RESULTS_DIR" ]; then
    echo "✗ 错误: 结果目录不存在 - $RESULTS_DIR"
    echo "请先运行: ./run_experiments.sh"
    exit 1
fi

# 统计日志文件数量
log_count=$(ls $RESULTS_DIR/*.log 2>/dev/null | wc -l)

if [ $log_count -eq 0 ]; then
    echo "✗ 错误: 找不到任何日志文件 (.log)"
    echo "请先运行: ./run_experiments.sh"
    exit 1
elif [ $log_count -lt 6 ]; then
    echo "⚠️  警告: 只找到 $log_count 个日志文件，应该有6个"
    echo "部分实验可能失败，分析将继续..."
else
    echo "✓ 找到 $log_count 个日志文件"
fi

# 列出所有日志文件
echo ""
echo "日志文件列表:"
ls -lh $RESULTS_DIR/*.log

# ----------------------------------------------------------------------------
# 3. 创建CSV结果文件并写入表头
# ----------------------------------------------------------------------------
csv_file="$RESULTS_DIR/performance_metrics.csv"

echo ""
echo "正在生成CSV结果文件: $csv_file"

# CSV表头定义
# 各列含义:
# - 实验名称: uniform_with_combiner等
# - 执行时间: 任务总耗时（秒）
# - Map输入记录: Map阶段读取的记录数
# - Map输出记录: Map阶段输出的键值对数
# - Combine输入记录: Combiner接收的记录数
# - Combine输出记录: Combiner输出的记录数
# - Reduce输入组: Reducer接收的key组数
# - Reduce输出记录: 最终输出的记录数
# - 数据压缩比: Map输出/Combiner输出，衡量Combiner效果
cat > $csv_file << 'EOF'
实验名称,执行时间(秒),Map输入记录,Map输出记录,Combine输入记录,Combine输出记录,Reduce输入组,Reduce输出记录,数据压缩比
EOF

echo "✓ CSV表头创建完成"

# ----------------------------------------------------------------------------
# 4. 提取每个实验的性能指标
# ----------------------------------------------------------------------------
echo ""
echo "正在从日志中提取性能指标..."
echo ""

# 遍历所有日志文件
for log in $RESULTS_DIR/*.log; do
    # 获取实验名称（去掉路径和.log后缀）
    exp_name=$(basename $log .log)

    echo "  处理: $exp_name"

    # ----------------------------------------------------------------------
    # 从日志中提取各项指标
    # ----------------------------------------------------------------------

    # 执行时间（我们在运行脚本中手动添加的）
    exec_time=$(grep "EXECUTION_TIME" $log | cut -d'=' -f2)

    # Map输入记录数
    # grep: 查找包含"Map input records"的行
    # tail -1: 取最后一行（防止有多次重试）
    # awk '{print $NF}': 打印最后一个字段（数字）
    map_input=$(grep "Map input records" $log | tail -1 | awk '{print $NF}')

    # Map输出记录数
    map_output=$(grep "Map output records" $log | tail -1 | awk '{print $NF}')

    # Combiner输入记录数（只有with-combiner版本有这个指标）
    combine_input=$(grep "Combine input records" $log | tail -1 | awk '{print $NF}')

    # Combiner输出记录数
    combine_output=$(grep "Combine output records" $log | tail -1 | awk '{print $NF}')

    # Reducer输入组数
    reduce_input=$(grep "Reduce input groups" $log | tail -1 | awk '{print $NF}')

    # Reducer输出记录数
    reduce_output=$(grep "Reduce output records" $log | tail -1 | awk '{print $NF}')

    # ----------------------------------------------------------------------
    # 计算数据压缩比
    # ----------------------------------------------------------------------

    # 如果没有Combiner（without版本），设置为N/A
    if [ -z "$combine_input" ] || [ "$combine_input" == "0" ]; then
        combine_input="N/A"
        combine_output="N/A"
        compression_ratio="1.0"  # 无压缩
    else
        # 计算压缩比 = Map输出记录数 / Combiner输出记录数
        # 例如: Map输出1000条，Combiner输出100条，压缩比=10
        # 压缩比越大，说明Combiner效果越好
        if [ "$combine_output" != "0" ]; then
            # bc: 命令行计算器，scale=2表示保留2位小数
            compression_ratio=$(echo "scale=2; $map_output / $combine_output" | bc)
        else
            compression_ratio="N/A"
        fi
    fi

    # ----------------------------------------------------------------------
    # 将数据写入CSV
    # ----------------------------------------------------------------------
    echo "$exp_name,$exec_time,$map_input,$map_output,$combine_input,$combine_output,$reduce_input,$reduce_output,$compression_ratio" >> $csv_file
done

echo ""
echo "✓ 性能指标提取完成"

# ----------------------------------------------------------------------------
# 5. 显示CSV表格
# ----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  性能指标总览"
echo "=========================================="

# column命令：将CSV格式化为对齐的表格
# -t: 自动对齐列
# -s',': 使用逗号作为分隔符
column -t -s',' $csv_file

# ----------------------------------------------------------------------------
# 6. 详细分析 - Uniform数据集
# ----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  详细分析报告"
echo "=========================================="

echo ""
echo "【数据集1: Uniform - 均匀分布】"
echo "特征: 所有单词出现频率相近，数据分布均匀"
echo "-------------------------------------------"

# 从CSV中提取uniform的两个实验数据
uniform_without=$(grep "uniform_without" $csv_file | cut -d',' -f2)
uniform_with=$(grep "uniform_with" $csv_file | cut -d',' -f2)

# 检查数据是否存在
if [ -n "$uniform_without" ] && [ -n "$uniform_with" ]; then
    # 计算性能提升百分比
    # 公式: (不带Combiner耗时 - 带Combiner耗时) / 不带Combiner耗时 * 100
    improvement=$(echo "scale=2; ($uniform_without - $uniform_with) / $uniform_without * 100" | bc)

    echo "  Without Combiner: ${uniform_without}秒"
    echo "  With Combiner:    ${uniform_with}秒"
    echo "  性能提升:         ${improvement}%"

    # 提取压缩比
    compression=$(grep "uniform_with" $csv_file | cut -d',' -f9)
    echo "  数据压缩比:       ${compression}:1"

    # 分析结论
    if (( $(echo "$improvement > 20" | bc -l) )); then
        echo "  ✓ 结论: Combiner显著提升性能，减少了网络传输"
    else
        echo "  ⚠️  结论: Combiner提升有限"
    fi
else
    echo "  ✗ 警告: 缺少实验数据"
fi

# ----------------------------------------------------------------------------
# 7. 详细分析 - Skewed数据集
# ----------------------------------------------------------------------------
echo ""
echo "【数据集2: Skewed - 数据倾斜】"
echo "特征: 少数热点词(如'the','of')占据大量记录"
echo "-------------------------------------------"

skewed_without=$(grep "skewed_without" $csv_file | cut -d',' -f2)
skewed_with=$(grep "skewed_with" $csv_file | cut -d',' -f2)

if [ -n "$skewed_without" ] && [ -n "$skewed_with" ]; then
    improvement=$(echo "scale=2; ($skewed_without - $skewed_with) / $skewed_without * 100" | bc)

    echo "  Without Combiner: ${skewed_without}秒"
    echo "  With Combiner:    ${skewed_with}秒"
    echo "  性能提升:         ${improvement}%"

    compression=$(grep "skewed_with" $csv_file | cut -d',' -f9)
    echo "  数据压缩比:       ${compression}:1"

    if (( $(echo "$improvement > 30" | bc -l) )); then
        echo "  ✓ 结论: Combiner对热点词合并效果极佳"
    else
        echo "  ⚠️  结论: 效果低于预期"
    fi
else
    echo "  ✗ 警告: 缺少实验数据"
fi

# ----------------------------------------------------------------------------
# 8. 详细分析 - Unique数据集
# ----------------------------------------------------------------------------
echo ""
echo "【数据集3: Unique - 高唯一性】"
echo "特征: 几乎每个单词都唯一，重复度极低"
echo "-------------------------------------------"

unique_without=$(grep "unique_without" $csv_file | cut -d',' -f2)
unique_with=$(grep "unique_with" $csv_file | cut -d',' -f2)

if [ -n "$unique_without" ] && [ -n "$unique_with" ]; then
    # 对于unique数据，Combiner可能反而增加耗时
    diff=$(echo "scale=2; $unique_with - $unique_without" | bc)

    echo "  Without Combiner: ${unique_without}秒"
    echo "  With Combiner:    ${unique_with}秒"
    echo "  时间差异:         ${diff}秒"

    compression=$(grep "unique_with" $csv_file | cut -d',' -f9)
    echo "  数据压缩比:       ${compression}:1"

    # 分析Combiner的负面影响
    if (( $(echo "$compression < 1.5" | bc -l) )); then
        echo "  ⚠️  警告: 压缩比接近1，Combiner几乎无效"
    fi

    if (( $(echo "$diff > 0" | bc -l) )); then
        echo "  ⚠️  警告: Combiner反而增加了 ${diff}秒"
        echo "     原因: 数据无重复，Combiner额外处理成本 > 收益"
    fi

    echo "  ✓ 结论: 高唯一性数据不适合使用Combiner"
else
    echo "  ✗ 警告: 缺少实验数据"
fi

# ----------------------------------------------------------------------------
# 9. 总结和建议
# ----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  实验结论与建议"
echo "=========================================="
echo ""
echo "【核心发现】"
echo "1. 均匀分布数据(Uniform):"
echo "   - Combiner显著减少网络传输量"
echo "   - 性能提升明显"
echo ""
echo "2. 数据倾斜场景(Skewed):"
echo "   - Combiner对热点词的合并效果最佳"
echo "   - 大幅减少Reducer负载"
echo ""
echo "3. 高唯一性数据(Unique):"
echo "   - Combiner几乎无效"
echo "   - 额外处理成本可能导致性能下降"
echo ""
echo "【实践建议】"
echo "✓ 使用Combiner的场景:"
echo "  - 数据重复度高 (>30%)"
echo "  - 存在热点key"
echo "  - 网络带宽是瓶颈"
echo ""
echo "✗ 避免使用Combiner的场景:"
echo "  - 数据唯一性高 (>90%)"
echo "  - 数据量很小"
echo "  - Combiner逻辑复杂耗时"
echo ""
echo "【性能调优建议】"
echo "1. 先分析数据特征 (唯一性、重复度)"
echo "2. 小规模测试对比性能"
echo "3. 监控网络传输和CPU开销"
echo "4. 根据实际场景动态调整"
echo ""
echo "=========================================="
echo "  分析完成!"
echo "=========================================="
echo ""
echo "结果文件: $csv_file"
echo "日志目录: $RESULTS_DIR"
echo "=========================================="