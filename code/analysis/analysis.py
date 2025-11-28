import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import re
import os
import sys

# ==========================================
# 配置部分
# ==========================================
RESULTS_DIR = '../results'  # 数据文件夹名称
OUTPUT_IMAGE = "four_plots_final.png"  # 输出图片名称

# 检查文件夹是否存在
if not os.path.exists(RESULTS_DIR):
    print(f"错误: 找不到文件夹 '{RESULTS_DIR}'。请确保数据文件都在该文件夹内。")
    sys.exit(1)

# 设置绘图风格
sns.set_theme(style="whitegrid")
palette = 'viridis'
plt.rcParams['font.sans-serif'] = ['DejaVu Sans']  # 英文通用字体
plt.rcParams['axes.unicode_minus'] = False

# ==========================================
# 1. 读取 CSV（包含执行时间）
# ==========================================
csv_path = os.path.join(RESULTS_DIR, 'performance_metrics.csv')
print(f"正在读取: {csv_path}")

try:
    # 指定 utf-8 编码以防乱码
    df_csv = pd.read_csv(csv_path, encoding='utf-8')
except FileNotFoundError:
    print("错误: 找不到 performance_metrics.csv")
    sys.exit(1)

# 映射中文列名到英文，避免绘图时字体报错
df_csv['Experiment'] = df_csv['实验名称']
# 假设CSV里列名是 '执行时间(秒)'，我们将其重命名方便绘图
if '执行时间(秒)' in df_csv.columns:
    df_csv['Execution Time (s)'] = df_csv['执行时间(秒)']
else:
    # 如果你的CSV列名不同，请在这里调整
    df_csv['Execution Time (s)'] = df_csv.iloc[:, 1]  # 尝试取第2列

# ==========================================
# 2. 解析日志（包含 CPU 时间）
# ==========================================
log_files = [
    'skewed_with_combiner.log', 'skewed_without_combiner.log',
    'uniform_with_combiner.log', 'uniform_without_combiner.log',
    'unique_with_combiner.log', 'unique_without_combiner.log'
]


def take(pattern, text):
    """正则提取数值，找不到返回0"""
    m = re.search(pattern, text)
    return int(m.group(1)) if m else 0


def parse_log(filename):
    """读取并解析单个日志文件"""
    file_path = os.path.join(RESULTS_DIR, filename)

    if not os.path.exists(file_path):
        print(f"警告: 找不到日志文件 {filename}，将跳过。")
        return None

    with open(file_path, 'r', encoding='utf-8') as f:
        txt = f.read()

    return {
        'Map CPU Time (ms)': take(r"Total vcore-milliseconds taken by all map tasks=(\d+)", txt),
        'Reduce CPU Time (ms)': take(r"Total vcore-milliseconds taken by all reduce tasks=(\d+)", txt),
        'Reduce Shuffle Bytes': take(r"Reduce shuffle bytes=(\d+)", txt),
        'Spilled Records': take(r"Spilled Records=(\d+)", txt),
        'Map Output Bytes': take(r"Map output bytes=(\d+)", txt)
    }


rows = []
for f in log_files:
    data = parse_log(f)
    if data:
        # 提取数据集名称和 Combiner 状态
        ds = 'Skewed' if 'skewed' in f else ('Uniform' if 'uniform' in f else 'Unique')
        cb = 'Without Combiner' if 'without' in f else 'With Combiner'

        data['Dataset'] = ds
        data['Combiner'] = cb
        # 保持与 CSV 中 'Experiment' 列一致的键值，通常是去除 .log
        data['Experiment'] = f.replace('.log', '')
        rows.append(data)

if not rows:
    print("错误: 没有成功解析任何日志文件。")
    sys.exit(1)

df_log = pd.DataFrame(rows)

# ==========================================
# 3. 合并数据
# ==========================================
# 确保 CSV 中的 Experiment 列格式和 Log 中的一致 (如果不一致需要在这里处理字符串)
df = pd.merge(df_csv, df_log, on='Experiment', how='inner')

if df.empty:
    print("错误: CSV 和日志文件合并后数据为空。请检查 '实验名称' 和日志文件名是否对应。")
    print(f"CSV Experiments: {df_csv['Experiment'].tolist()}")
    print(f"Log Experiments: {df_log['Experiment'].tolist()}")
    sys.exit(1)

# 计算总 CPU 时间 (秒)
df['Total CPU Time (s)'] = (df['Map CPU Time (ms)'] + df['Reduce CPU Time (ms)']) / 1000

print("数据合并完成，开始绘图...")

# ==========================================
# 4. 开始绘图
# ==========================================
fig, axes = plt.subplots(2, 2, figsize=(18, 12))

# -------------------------------------
# 图 1：执行时间
# -------------------------------------
sns.barplot(
    data=df, x='Dataset', y='Execution Time (s)', hue='Combiner',
    ax=axes[0, 0], palette=palette
)
axes[0, 0].set_title('Execution Time (Wall Clock)')
axes[0, 0].set_ylabel('Seconds')

# 标注数值
for c in axes[0, 0].containers:
    axes[0, 0].bar_label(c, fmt="%.2f s", padding=3)

# -------------------------------------
# 图 2：Shuffle 数据量
# -------------------------------------
sns.barplot(
    data=df, x='Dataset', y='Reduce Shuffle Bytes', hue='Combiner',
    ax=axes[0, 1], palette=palette
)
axes[0, 1].set_title('Shuffle Data Volume (Bytes)')
axes[0, 1].set_yscale('log')  # 对数坐标更清晰

# -------------------------------------
# 图 3：Spilled Records
# -------------------------------------
sns.barplot(
    data=df, x='Dataset', y='Spilled Records', hue='Combiner',
    ax=axes[1, 0], palette=palette
)
axes[1, 0].set_title('Spilled Records')
axes[1, 0].set_yscale('log')

# -------------------------------------
# 图 4：CPU Time Breakdown (堆叠柱状图)
# -------------------------------------
ax4 = axes[1, 1]

# 准备堆叠图数据
# 注意：为了堆叠图对其，我们需要 x 轴的顺序一致。
# 我们可以直接利用 DataFrame 的索引或行顺序
x_labels = df['Dataset'] + "\n" + df['Combiner']
map_cpu = df['Map CPU Time (ms)']
reduce_cpu = df['Reduce CPU Time (ms)']

# 颜色
colors = sns.color_palette("viridis", 2)

# 绘制
ax4.bar(x_labels, map_cpu, label='Map CPU Time', color=colors[0])
ax4.bar(x_labels, reduce_cpu, bottom=map_cpu, label='Reduce CPU Time', color=colors[1])

ax4.set_title('CPU Time Breakdown: Map vs Reduce')
ax4.set_ylabel('Time (ms)')
ax4.tick_params(axis='x', rotation=45)  # 旋转标签防止重叠
ax4.legend()

# ==========================================
# 5. 保存与显示
# ==========================================
plt.tight_layout()
plt.savefig(OUTPUT_IMAGE, dpi=300)
print(f"绘图完成！图片已保存为: {OUTPUT_IMAGE}")
