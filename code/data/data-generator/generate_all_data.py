#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
统一的数据生成脚本
生成三种不同分布特征的WordCount测试数据
所有数据格式统一：每行包含多个单词
"""

import random
import time
import os

# ==================== 统一配置 ====================
NUM_LINES = 1000000          # 总行数：100万行
WORDS_PER_LINE = 50          # 每行单词数：50个
NUM_UNIQUE_WORDS = 10000     # 唯一单词总数：1万个

# 数据倾斜配置
HOT_WORD_COUNT = 200         # 热点单词数：200个 (2%)
COLD_WORD_COUNT = 9800       # 冷门单词数：9800个 (98%)
HOT_RATIO = 0.8              # 热点单词频率占比：80%

# 输出目录（上级目录，即data文件夹）
OUTPUT_DIR = ".."

# ==================== 工具函数 ====================
def print_header(title):
    """打印标题"""
    print("\n" + "="*70)
    print(f"  {title}")
    print("="*70)

def print_progress(current, total, start_time, interval=100000):
    """打印进度条"""
    if (current + 1) % interval == 0:
        elapsed = time.time() - start_time
        progress = (current + 1) / total * 100
        speed = (current + 1) / elapsed
        eta = (total - current - 1) / speed
        print(f"进度: {progress:5.1f}% ({current+1:>8,}/{total:,}) | "
              f"耗时: {elapsed:6.1f}s | 速度: {speed:6.0f} 行/s | "
              f"预计剩余: {eta:6.1f}s")

def print_summary(output_file, num_lines, words_per_line, num_unique,
                  total_time, extra_info=None):
    """打印生成摘要"""
    total_words = num_lines * words_per_line
    file_size = os.path.getsize(output_file) / (1024 * 1024)  # MB

    print("\n" + "-"*70)
    print("【文件信息】")
    print(f"  文件路径: {output_file}")
    print(f"  文件大小: {file_size:.2f} MB")
    print(f"  总行数: {num_lines:,}")
    print(f"  总单词数: {total_words:,}")
    print(f"  唯一单词数: {num_unique:,}")

    print(f"\n【性能指标】")
    print(f"  生成耗时: {total_time:.2f} 秒")
    print(f"  处理速度: {num_lines/total_time:.0f} 行/秒")

    print(f"\n【Combiner效果预估】")
    print(f"  Map输出记录数: {total_words:,}")
    print(f"  Combiner后记录数: ~{num_unique:,}")
    print(f"  数据压缩比: ~{total_words/num_unique:.1f}:1")

    if extra_info:
        print(f"\n【特殊说明】")
        for line in extra_info:
            print(f"  {line}")

    print("="*70)

# ==================== 1. 均匀分布数据 ====================
def generate_uniform_data():
    """生成均匀分布的数据"""
    output_file = os.path.join(OUTPUT_DIR, "uniform_data.txt")

    print_header("生成均匀分布数据 - 模拟结构化日志场景")
    print(f"配置: {NUM_LINES:,}行 × {WORDS_PER_LINE}词/行 = {NUM_LINES*WORDS_PER_LINE:,}个单词")
    print(f"唯一单词数: {NUM_UNIQUE_WORDS:,}")
    print(f"理论每个单词出现次数: {NUM_LINES*WORDS_PER_LINE/NUM_UNIQUE_WORDS:.0f}")
    print()

    start_time = time.time()

    # 生成单词池
    print("生成单词池...")
    word_pool = [f"word_{i:05d}" for i in range(NUM_UNIQUE_WORDS)]

    # 写入数据
    print(f"写入数据: {output_file}")
    print()

    with open(output_file, 'w') as f:
        for i in range(NUM_LINES):
            words = [random.choice(word_pool) for _ in range(WORDS_PER_LINE)]
            f.write(' '.join(words) + '\n')
            print_progress(i, NUM_LINES, start_time)

    total_time = time.time() - start_time

    extra_info = [
        "✓ 所有单词出现频率相近",
        "✓ Combiner预期效果显著",
        "✓ 适合验证Combiner的基本功能"
    ]

    print_summary(output_file, NUM_LINES, WORDS_PER_LINE,
                  NUM_UNIQUE_WORDS, total_time, extra_info)

    return output_file

# ==================== 2. 数据倾斜分布 ====================
def generate_skewed_data():
    """生成数据倾斜的数据"""
    output_file = os.path.join(OUTPUT_DIR, "skewed_data.txt")

    print_header("生成数据倾斜分布数据 - 模拟热点词汇场景")
    print(f"配置: {NUM_LINES:,}行 × {WORDS_PER_LINE}词/行 = {NUM_LINES*WORDS_PER_LINE:,}个单词")
    print(f"热点单词: {HOT_WORD_COUNT}个 (占{HOT_WORD_COUNT/(HOT_WORD_COUNT+COLD_WORD_COUNT)*100:.1f}%), 频率占比{HOT_RATIO*100:.0f}%")
    print(f"冷门单词: {COLD_WORD_COUNT}个 (占{COLD_WORD_COUNT/(HOT_WORD_COUNT+COLD_WORD_COUNT)*100:.1f}%), 频率占比{(1-HOT_RATIO)*100:.0f}%")

    total_words = NUM_LINES * WORDS_PER_LINE
    hot_total = int(total_words * HOT_RATIO)
    cold_total = total_words - hot_total
    hot_avg = hot_total / HOT_WORD_COUNT
    cold_avg = cold_total / COLD_WORD_COUNT

    print(f"倾斜比例: {hot_avg/cold_avg:.1f}:1 (热点词平均出现{hot_avg:.0f}次 vs 冷门词{cold_avg:.0f}次)")
    print()

    start_time = time.time()

    # 生成单词池
    print("生成单词池...")
    hot_words = [f"hot_word_{i:03d}" for i in range(HOT_WORD_COUNT)]
    cold_words = [f"cold_word_{i:04d}" for i in range(COLD_WORD_COUNT)]

    # 写入数据
    print(f"写入数据: {output_file}")
    print()

    with open(output_file, 'w') as f:
        for i in range(NUM_LINES):
            words = []
            for _ in range(WORDS_PER_LINE):
                if random.random() < HOT_RATIO:
                    words.append(random.choice(hot_words))
                else:
                    words.append(random.choice(cold_words))
            f.write(' '.join(words) + '\n')
            print_progress(i, NUM_LINES, start_time)

    total_time = time.time() - start_time

    extra_info = [
        f"⚠️  数据存在显著倾斜 (80-20原则)",
        f"✓ Combiner对热点词效果显著",
        f"⚠️  可能导致Reducer负载不均衡",
        f"✓ 适合验证Combiner在倾斜场景的表现"
    ]

    print_summary(output_file, NUM_LINES, WORDS_PER_LINE,
                  HOT_WORD_COUNT + COLD_WORD_COUNT, total_time, extra_info)

    return output_file

# ==================== 3. 高唯一性数据 ====================
def generate_unique_data():
    """生成高唯一性的数据（几乎无重复）"""
    output_file = os.path.join(OUTPUT_DIR, "unique_data.txt")

    print_header("生成高唯一性数据 - 模拟唯一标识符场景")
    print(f"配置: {NUM_LINES:,}行 × {WORDS_PER_LINE}词/行 = {NUM_LINES*WORDS_PER_LINE:,}个单词")
    print(f"目标唯一性: >95%")
    print(f"场景: UUID、会话ID、唯一标识符等")
    print()

    start_time = time.time()

    # 写入数据
    print(f"写入数据: {output_file}")
    print()

    word_counter = 0
    with open(output_file, 'w') as f:
        for i in range(NUM_LINES):
            words = []
            for _ in range(WORDS_PER_LINE):
                # 格式: uuid_序号 (保证唯一性)
                words.append(f"uuid_{word_counter:08d}")
                word_counter += 1
            f.write(' '.join(words) + '\n')
            print_progress(i, NUM_LINES, start_time)

    total_time = time.time() - start_time

    total_words = NUM_LINES * WORDS_PER_LINE

    extra_info = [
        f"✗ 几乎每个单词都是唯一的 (100%唯一性)",
        f"✗ Combiner无法减少数据量",
        f"✗ 使用Combiner反而增加计算开销",
        f"✓ 适合验证'不是所有场景都适合Combiner'"
    ]

    print_summary(output_file, NUM_LINES, WORDS_PER_LINE,
                  total_words, total_time, extra_info)

    return output_file

# ==================== 主函数 ====================
def main():
    """主函数：生成所有测试数据"""
    # 确保输出目录存在
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"创建输出目录: {OUTPUT_DIR}")

    print("\n" + "█"*70)
    print("  MapReduce Combiner 性能分析 - 测试数据生成器")
    print("█"*70)
    print(f"\n统一配置:")
    print(f"  - 总行数: {NUM_LINES:,}")
    print(f"  - 每行单词数: {WORDS_PER_LINE}")
    print(f"  - 总单词数: {NUM_LINES * WORDS_PER_LINE:,}")
    print(f"  - 输出目录: {OUTPUT_DIR}")
    print(f"\n将生成三种数据集:")
    print(f"  1. uniform_data.txt  - 均匀分布")
    print(f"  2. skewed_data.txt   - 数据倾斜")
    print(f"  3. unique_data.txt   - 高唯一性")
    print()

    input("按 Enter 键开始生成数据...")

    total_start = time.time()

    # 生成三种数据
    files = []
    files.append(generate_uniform_data())
    files.append(generate_skewed_data())
    files.append(generate_unique_data())

    total_time = time.time() - total_start

    # 总结
    print("\n" + "█"*70)
    print("  所有数据生成完成!")
    print("█"*70)
    print(f"\n生成的文件:")
    for i, f in enumerate(files, 1):
        size = os.path.getsize(f) / (1024 * 1024)
        print(f"  {i}. {os.path.basename(f):20s} ({size:.2f} MB)")

    print(f"\n总耗时: {total_time:.2f} 秒")
    print(f"\n下一步:")
    print(f"  1. 运行 validate_data.py 验证数据特征")
    print(f"  2. 使用 scp 或 WinSCP 上传数据到虚拟机")
    print(f"     scp {OUTPUT_DIR}/*.txt root@192.168.204.132:/export/data/")
    print("█"*70 + "\n")

if __name__ == "__main__":
    main()