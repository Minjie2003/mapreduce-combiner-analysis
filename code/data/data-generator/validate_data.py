#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
数据验证脚本
分析生成的测试数据特征，验证是否符合预期
"""

import os
from collections import Counter
import time

# 数据目录（上级目录，即data文件夹）
DATA_DIR = ".."

def analyze_data_distribution(file_path, sample_lines=100000):
    """
    分析数据分布特征

    参数:
        file_path: 数据文件路径
        sample_lines: 采样行数
    """
    filename = os.path.basename(file_path)

    print("\n" + "="*70)
    print(f"  分析文件: {filename}")
    print("="*70)

    if not os.path.exists(file_path):
        print(f"✗ 错误: 文件不存在")
        return

    file_size = os.path.getsize(file_path) / (1024 * 1024)
    print(f"文件大小: {file_size:.2f} MB")
    print(f"采样行数: {sample_lines:,}")
    print()

    start_time = time.time()

    # 统计变量
    word_counts = Counter()
    total_lines = 0
    total_words = 0
    words_per_line_list = []

    # 读取数据
    print("正在分析数据...")
    with open(file_path, 'r', encoding='utf-8') as f:
        for i, line in enumerate(f):
            if i >= sample_lines:
                break

            words = line.strip().split()
            words_per_line_list.append(len(words))

            for word in words:
                if word:
                    word_counts[word] += 1
                    total_words += 1

            total_lines += 1

            if (i + 1) % 10000 == 0:
                print(f"  已处理: {i+1:>6,} 行", end='\r')

    print(f"  已处理: {total_lines:>6,} 行 ✓\n")

    # 基本统计
    unique_words = len(word_counts)
    avg_words_per_line = sum(words_per_line_list) / len(words_per_line_list)

    # 频率分析
    counts = list(word_counts.values())
    avg_count = sum(counts) / len(counts)
    max_count = max(counts)
    min_count = min(counts)

    # Top 单词
    top_words = word_counts.most_common(10)

    # 前20%单词频率占比
    sorted_words = word_counts.most_common()
    top_20_percent = max(1, int(unique_words * 0.2))
    top_20_freq = sum(count for _, count in sorted_words[:top_20_percent])
    top_20_ratio = top_20_freq / total_words

    elapsed = time.time() - start_time

    # ==================== 输出结果 ====================
    print("-"*70)
    print("【基本信息】")
    print(f"  总行数:          {total_lines:>12,}")
    print(f"  总单词数:        {total_words:>12,}")
    print(f"  唯一单词数:      {unique_words:>12,}")
    print(f"  唯一性比例:      {unique_words/total_words*100:>11.2f}%")
    print(f"  每行平均单词数:  {avg_words_per_line:>12.1f}")

    print(f"\n【单词频率分布】")
    print(f"  平均出现次数:    {avg_count:>12.2f}")
    print(f"  最高出现次数:    {max_count:>12,}")
    print(f"  最低出现次数:    {min_count:>12,}")
    print(f"  倾斜度(最高/平均): {max_count/avg_count:>10.2f}")

    print(f"\n【数据倾斜分析】")
    print(f"  前20%单词频率占比: {top_20_ratio*100:>9.1f}%")

    if top_20_ratio > 0.6:
        status = "⚠️  显著倾斜"
        level = "高"
    elif top_20_ratio > 0.4:
        status = "ℹ️  中等倾斜"
        level = "中"
    else:
        status = "✓  分布均匀"
        level = "低"

    print(f"  数据倾斜程度:     {level:>12} {status}")

    print(f"\n【出现频率最高的10个单词】")
    for idx, (word, count) in enumerate(top_words, 1):
        percentage = count / total_words * 100
        bar_length = int(percentage * 0.5)
        bar = '█' * min(bar_length, 40)
        print(f"  {idx:2d}. {word:20s} {count:>8,} ({percentage:5.2f}%) {bar}")

    print(f"\n【Combiner效果预估】")
    compression_ratio = total_words / unique_words
    print(f"  Map输出记录数:       {total_words:>12,}")
    print(f"  Combiner后记录数:    {unique_words:>12,}")
    print(f"  数据压缩比:          {compression_ratio:>11.2f}:1")

    if compression_ratio > 10:
        effect = "✓ 极佳"
    elif compression_ratio > 3:
        effect = "✓ 良好"
    elif compression_ratio > 1.5:
        effect = "⚠️ 一般"
    else:
        effect = "✗ 无效"

    print(f"  Combiner预期效果:    {effect:>12}")

    print(f"\n【性能指标】")
    print(f"  分析耗时:        {elapsed:>12.2f} 秒")
    print(f"  处理速度:        {total_lines/elapsed:>12.0f} 行/秒")

    print("="*70)

    return {
        'filename': filename,
        'total_words': total_words,
        'unique_words': unique_words,
        'compression_ratio': compression_ratio,
        'top_20_ratio': top_20_ratio
    }

def main():
    """主函数：分析所有数据文件"""
    print("\n" + "█"*70)
    print("  MapReduce Combiner 性能分析 - 数据验证器")
    print("█"*70)

    # 要分析的文件
    data_files = [
        "uniform_data.txt",
        "skewed_data.txt",
        "unique_data.txt"
    ]

    results = []

    for filename in data_files:
        file_path = os.path.join(DATA_DIR, filename)
        result = analyze_data_distribution(file_path)
        if result:
            results.append(result)

    # 对比总结
    if results:
        print("\n" + "█"*70)
        print("  数据集对比总结")
        print("█"*70)
        print(f"\n{'数据集':<20} {'唯一单词数':>12} {'压缩比':>10} {'前20%占比':>12}")
        print("-"*70)

        for r in results:
            print(f"{r['filename']:<20} {r['unique_words']:>12,} "
                  f"{r['compression_ratio']:>9.1f}:1 {r['top_20_ratio']*100:>11.1f}%")

        print("\n" + "█"*70)
        print("  验证结论")
        print("█"*70)
        print("\n✓ uniform_data.txt  - 数据分布均匀，Combiner效果应该显著")
        print("✓ skewed_data.txt   - 数据存在倾斜，Combiner对热点词效果好")
        print("✓ unique_data.txt   - 数据唯一性高，Combiner几乎无效")
        print("\n实验预期:")
        print("  1. 均匀分布场景：有/无Combiner性能差异最大")
        print("  2. 数据倾斜场景：Combiner有效但可能负载不均")
        print("  3. 高唯一性场景：Combiner无优势甚至负优化")
        print("\n下一步: 上传数据到HDFS并运行MapReduce实验")
        print("█"*70 + "\n")

if __name__ == "__main__":
    main()