#!/bin/bash
# ============================================================================
# 脚本名称: upload_data.sh
# 功能描述: 上传测试数据到HDFS
# 注意事项: 需要先生成数据文件
# ============================================================================

# ----------------------------------------------------------------------------
# 1. 全局配置
# ----------------------------------------------------------------------------
PROJECT_DIR=/export/data/code
DATA_DIR=$PROJECT_DIR/data

# 根据当前用户自动设置HDFS路径
CURRENT_USER=$(whoami)
HDFS_INPUT_DIR=/user/$CURRENT_USER/input

echo "=========================================="
echo "  上传数据到HDFS"
echo "=========================================="
echo "当前用户: $CURRENT_USER"
echo "本地数据目录: $DATA_DIR"
echo "HDFS目标目录: $HDFS_INPUT_DIR"
echo ""

# ----------------------------------------------------------------------------
# 2. 检查本地数据文件是否存在
# ----------------------------------------------------------------------------
echo "步骤1: 检查本地数据文件..."

if [ ! -d "$DATA_DIR" ]; then
    echo "✗ 错误: 数据目录不存在 - $DATA_DIR"
    exit 1
fi

# 检查三个数据文件
declare -a datasets=("uniform_data.txt" "skewed_data.txt" "unique_data.txt")
missing_count=0

for dataset in "${datasets[@]}"; do
    if [ -f "$DATA_DIR/$dataset" ]; then
        size=$(du -h "$DATA_DIR/$dataset" | cut -f1)
        echo "  ✓ 找到: $dataset ($size)"
    else
        echo "  ✗ 缺失: $dataset"
        missing_count=$((missing_count + 1))
    fi
done

if [ $missing_count -gt 0 ]; then
    echo ""
    echo "✗ 错误: 缺少 $missing_count 个数据文件"
    echo "请先生成数据: cd $DATA_DIR/data-generator && python generate_all_data.py"
    exit 1
fi

echo "✓ 所有数据文件检查通过"

# ----------------------------------------------------------------------------
# 3. 清理并创建HDFS目录
# ----------------------------------------------------------------------------
echo ""
echo "步骤2: 准备HDFS目录..."

# 检查HDFS连接
if ! hdfs dfs -ls / &>/dev/null; then
    echo "✗ 错误: 无法连接到HDFS，请检查Hadoop配置"
    exit 1
fi

# 如果目录存在，先删除
if hdfs dfs -test -d $HDFS_INPUT_DIR 2>/dev/null; then
    echo "  删除旧目录: $HDFS_INPUT_DIR"
    hdfs dfs -rm -r $HDFS_INPUT_DIR
fi

# 创建新目录
hdfs dfs -mkdir -p $HDFS_INPUT_DIR
echo "✓ HDFS目录创建完成"

# ----------------------------------------------------------------------------
# 4. 上传数据文件到HDFS
# ----------------------------------------------------------------------------
echo ""
echo "步骤3: 上传数据文件..."

upload_count=0
for dataset in "${datasets[@]}"; do
    echo ""
    echo "  上传: $dataset"

    local_file="$DATA_DIR/$dataset"

    if hdfs dfs -put $local_file $HDFS_INPUT_DIR/ 2>&1; then
        # 验证上传成功
        if hdfs dfs -test -e $HDFS_INPUT_DIR/$dataset; then
            hdfs_size=$(hdfs dfs -du -h $HDFS_INPUT_DIR/$dataset | awk '{print $1$2}')
            echo "  ✓ 上传成功 (HDFS大小: $hdfs_size)"
            upload_count=$((upload_count + 1))
        else
            echo "  ✗ 上传验证失败"
        fi
    else
        echo "  ✗ 上传失败"
    fi
done

# ----------------------------------------------------------------------------
# 5. 验证上传结果
# ----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  上传结果汇总"
echo "=========================================="
echo "总文件数: ${#datasets[@]}"
echo "成功上传: $upload_count"

if [ $upload_count -eq ${#datasets[@]} ]; then
    echo "✓ 所有数据文件上传成功!"
else
    echo "✗ 部分文件上传失败"
    exit 1
fi

echo ""
echo "HDFS目录内容:"
hdfs dfs -ls -h $HDFS_INPUT_DIR

echo ""
echo "=========================================="
echo "下一步操作:"
echo "  编译代码: ./compile_and_package.sh"
echo "=========================================="