#!/bin/bash
# ============================================================================
# 脚本名称: compile_and_package.sh
# 功能描述: 编译MapReduce源代码并打包成JAR文件
# 注意事项: 需要先配置好Hadoop环境变量
# ============================================================================

# ----------------------------------------------------------------------------
# 1. 全局配置
# ----------------------------------------------------------------------------
PROJECT_DIR=/export/data/code
BUILD_DIR=$PROJECT_DIR/build

# 定义源代码路径
WITHOUT_COMBINER_SRC=$PROJECT_DIR/mapreduce/without-combiner
WITH_COMBINER_SRC=$PROJECT_DIR/mapreduce/with-combiner

# 定义编译输出路径
WITHOUT_COMBINER_BUILD=$BUILD_DIR/without-combiner
WITH_COMBINER_BUILD=$BUILD_DIR/with-combiner

echo "=========================================="
echo "  编译和打包MapReduce代码"
echo "=========================================="
echo "项目目录: $PROJECT_DIR"
echo "编译目录: $BUILD_DIR"
echo ""

# ----------------------------------------------------------------------------
# 2. 清理旧的编译文件
# ----------------------------------------------------------------------------
echo "步骤1: 清理旧的编译文件..."

# 删除旧的build目录
if [ -d "$BUILD_DIR" ]; then
    echo "  删除旧的 $BUILD_DIR"
    rm -rf $BUILD_DIR/*
fi

# 重新创建目录结构
mkdir -p $WITHOUT_COMBINER_BUILD
mkdir -p $WITH_COMBINER_BUILD

echo "✓ 清理完成"

# ----------------------------------------------------------------------------
# 3. 编译不带Combiner的版本
# ----------------------------------------------------------------------------
echo ""
echo "步骤2: 编译 without-combiner 版本..."
echo "  源代码目录: $WITHOUT_COMBINER_SRC"

# 进入源代码目录
cd $WITHOUT_COMBINER_SRC

# 检查源代码文件是否存在
if [ ! -d "com/hadoop/wordcount/without" ]; then
    echo "✗ 错误: 找不到源代码目录!"
    echo "请检查: $WITHOUT_COMBINER_SRC/com/hadoop/wordcount/without/"
    exit 1
fi

echo "  找到源文件:"
ls -la com/hadoop/wordcount/without/*.java

# javac 编译参数说明：
# -classpath $(hadoop classpath): 添加Hadoop的所有依赖库
# -d $WITHOUT_COMBINER_BUILD: 指定编译后的class文件输出目录
# com/hadoop/wordcount/without/*.java: 编译所有Java源文件
echo ""
echo "  开始编译..."
javac -classpath $(hadoop classpath) \
      -d $WITHOUT_COMBINER_BUILD \
      com/hadoop/wordcount/without/*.java

# 检查编译是否成功
if [ $? -eq 0 ]; then
    echo "  ✓ 编译成功"
    echo "  编译后的class文件:"
    find $WITHOUT_COMBINER_BUILD -name "*.class"
else
    echo "  ✗ 编译失败！"
    echo "  请检查:"
    echo "  1. Java版本是否正确 (java -version)"
    echo "  2. Hadoop环境变量是否配置 (hadoop version)"
    echo "  3. 源代码是否有语法错误"
    exit 1
fi

# 打包成JAR文件
echo ""
echo "  打包 JAR 文件..."
cd $WITHOUT_COMBINER_BUILD

# jar 命令参数说明：
# -c: 创建新的JAR文件
# -v: 显示详细输出（verbose）
# -f: 指定JAR文件名
# com/hadoop/wordcount/without/*.class: 要打包的class文件
jar -cvf wordcount-without-combiner.jar \
    com/hadoop/wordcount/without/*.class > /dev/null 2>&1

if [ -f "wordcount-without-combiner.jar" ]; then
    echo "  ✓ 生成: wordcount-without-combiner.jar"
    ls -lh wordcount-without-combiner.jar
else
    echo "  ✗ JAR打包失败"
    exit 1
fi

# ----------------------------------------------------------------------------
# 4. 编译带Combiner的版本
# ----------------------------------------------------------------------------
echo ""
echo "步骤3: 编译 with-combiner 版本..."
echo "  源代码目录: $WITH_COMBINER_SRC"

cd $WITH_COMBINER_SRC

# 检查源代码文件是否存在
if [ ! -d "com/hadoop/wordcount/with" ]; then
    echo "✗ 错误: 找不到源代码目录!"
    echo "请检查: $WITH_COMBINER_SRC/com/hadoop/wordcount/with/"
    exit 1
fi

echo "  找到源文件:"
ls -la com/hadoop/wordcount/with/*.java

echo ""
echo "  开始编译..."
javac -classpath $(hadoop classpath) \
      -d $WITH_COMBINER_BUILD \
      com/hadoop/wordcount/with/*.java

if [ $? -eq 0 ]; then
    echo "  ✓ 编译成功"
    echo "  编译后的class文件:"
    find $WITH_COMBINER_BUILD -name "*.class"
else
    echo "  ✗ 编译失败！"
    exit 1
fi

# 打包成JAR文件
echo ""
echo "  打包 JAR 文件..."
cd $WITH_COMBINER_BUILD

jar -cvf wordcount-with-combiner.jar \
    com/hadoop/wordcount/with/*.class > /dev/null 2>&1

if [ -f "wordcount-with-combiner.jar" ]; then
    echo "  ✓ 生成: wordcount-with-combiner.jar"
    ls -lh wordcount-with-combiner.jar
else
    echo "  ✗ JAR打包失败"
    exit 1
fi

# ----------------------------------------------------------------------------
# 5. 验证JAR文件内容
# ----------------------------------------------------------------------------
echo ""
echo "步骤4: 验证JAR文件内容..."

echo ""
echo "--- without-combiner JAR 内容 ---"
jar -tf $WITHOUT_COMBINER_BUILD/wordcount-without-combiner.jar | grep -E "\.class$"

echo ""
echo "--- with-combiner JAR 内容 ---"
jar -tf $WITH_COMBINER_BUILD/wordcount-with-combiner.jar | grep -E "\.class$"

# ----------------------------------------------------------------------------
# 6. 完成提示
# ----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  ✓ 编译打包完成!"
echo "=========================================="
echo ""
echo "生成的JAR文件:"
echo "1. Without Combiner:"
ls -lh $WITHOUT_COMBINER_BUILD/*.jar
echo ""
echo "2. With Combiner:"
ls -lh $WITH_COMBINER_BUILD/*.jar

echo ""
echo "下一步操作:"
echo "  运行实验: ./run_experiments.sh"
echo "=========================================="