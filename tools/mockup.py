# -*- coding: utf-8 -*-
"""SlidePlay 界面示意图（PIL 绘制，非真实渲染）"""
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
import numpy as np
import os
import sys

# 主题方案：a=蓝紫（默认），b=蓝粉
VARIANT = sys.argv[1] if len(sys.argv) > 1 else "a"
if VARIANT == "b":
    ACCENT = (38, 140, 249)    # 亮蓝
    HEART = (250, 74, 140)     # 粉
    GRAD2 = (250, 74, 140)     # 渐变终点=粉（与代码一致）
    SCHEME = "蓝粉方案"
else:
    ACCENT = (94, 107, 240)    # 蓝紫
    HEART = (255, 74, 120)     # 粉心
    GRAD2 = (150, 70, 200)     # 渐变终点（蓝→紫）
    SCHEME = "蓝紫方案"

SW, SH = 400, 866          # 屏幕
R = 58                    # 屏幕圆角
BEZEL = 14
PW, PH = SW + BEZEL * 2, SH + BEZEL * 2

FONT_DIR = r"C:\Windows\Fonts"

def font(sz, bold=False):
    for name in (["msyhbd.ttc", "msyh.ttc"] if bold else ["msyh.ttc", "simhei.ttf"]):
        p = os.path.join(FONT_DIR, name)
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, sz)
            except Exception:
                continue
    return ImageFont.load_default()

F_TITLE = font(26, True)
F_LBL = font(21, True)
F_CAP = font(15)
F_NAV = font(17, True)
F_SEC = font(12)
F_ROW = font(14)
F_ROWS = font(11)
F_CELL = font(10)

WHITE = (235, 235, 245)
GRAY = (140, 140, 145)
SEP = (58, 58, 60)
GREEN = ACCENT
RED = HEART

def gradient(w, h, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None]
    cols = (1 - t) * np.array(top) + t * np.array(bottom)
    arr = np.repeat(cols, w, axis=1).astype("uint8")
    return Image.fromarray(arr, "RGB")

def grad_capsule(img, box, c1, c2, radius):
    """在 img 上画一个横向渐变胶囊。"""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    t = np.linspace(0, 1, w)[None, :, None]
    cols = (1 - t) * np.array(c1)[None, None, :] + t * np.array(c2)[None, None, :]
    arr = np.repeat(cols, h, axis=0).astype("uint8")
    g = Image.fromarray(arr, "RGB")
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    img.paste(g, (x0, y0), m)

PALETTES = [
    ((26, 18, 54), (150, 46, 96)),
    ((12, 32, 64), (212, 96, 42)),
    ((18, 12, 42), (58, 122, 168)),
    ((34, 14, 46), (120, 60, 170)),
    ((10, 40, 42), (160, 140, 40)),
    ((40, 16, 24), (90, 40, 120)),
]

def fake_video(idx):
    top, bottom = PALETTES[idx % len(PALETTES)]
    img = gradient(SW, SH, top, bottom)
    ov = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    rng = (idx * 37 + 11) % 100
    # 太阳/月亮
    cx, cy, rr = 90 + (idx * 53) % 220, 180 + (idx * 97) % 260, 46 + idx * 7 % 30
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(255, 235, 200, 90))
    # 远山
    d.polygon([(0, SH), (SW // 3 - 40, 520 + rng % 60), (SW * 2 // 3 + 30, 640), (SW, SH)],
              fill=(0, 0, 0, 70))
    d.polygon([(0, SH), (SW // 2 + 60, 600 - rng % 50), (SW, 700), (SW, SH)],
              fill=(0, 0, 0, 100))
    img = Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB")
    return img

def island(img):
    d = ImageDraw.Draw(img)
    w, h = 126, 37
    x0, y0 = (SW - w) // 2, 14
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=h / 2, fill=(0, 0, 0))
    d.ellipse([x0 + w - 31, y0 + 11, x0 + w - 20, y0 + 26], fill=(14, 14, 20))

def screen_mask():
    m = Image.new("L", (SW, SH), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, SW - 1, SH - 1], radius=R, fill=255)
    return m

MASK = screen_mask()

def paste_phone(canvas, screen, x, y):
    bd = Image.new("L", (PW, PH), 0)
    ImageDraw.Draw(bd).rounded_rectangle([0, 0, PW - 1, PH - 1], radius=R + BEZEL, fill=255)
    frame = Image.new("RGB", (PW, PH), (8, 8, 10))
    canvas.paste(frame, (x, y), bd)
    canvas.paste(screen, (x + BEZEL, y + BEZEL), MASK)

def rtext(d, x_right, y, text, f, fill):
    w = d.textlength(text, font=f)
    d.text((x_right - w, y), text, font=f, fill=fill)

# ---- 手绘图标（避免字体缺字） ----

def icon_heart(d, cx, cy, s, color=RED):
    """以 (cx, cy) 为中心、宽 s 的实心心形。"""
    r = s / 4.0
    d.ellipse([cx - s / 2, cy - s / 2, cx - s / 2 + 2 * r, cy - s / 2 + 2 * r], fill=color)
    d.ellipse([cx + s / 2 - 2 * r, cy - s / 2, cx + s / 2, cy - s / 2 + 2 * r], fill=color)
    d.polygon([(cx - s / 2 + r * 0.35, cy - r * 0.15),
               (cx + s / 2 - r * 0.35, cy - r * 0.15),
               (cx, cy + s / 2)], fill=color)

def icon_check(d, x, y, s, color=GREEN):
    d.line([(x, y + s * 0.55), (x + s * 0.38, y + s * 0.85), (x + s, y + s * 0.1)],
           fill=color, width=3, joint="curve")

def icon_circle(d, x, y, s, color=GRAY):
    d.ellipse([x, y, x + s, y + s], outline=color, width=2)

def icon_check_circle(d, x, y, s, color=GREEN):
    d.ellipse([x, y, x + s, y + s], fill=color)
    icon_check(d, x + s * 0.24, y + s * 0.18, s * 0.52, color=(255, 255, 255))

def icon_close(d, cx, cy, r, color=GRAY):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=2)
    k = r * 0.55
    d.line([(cx - k, cy - k), (cx + k, cy + k)], fill=color, width=2)
    d.line([(cx - k, cy + k), (cx + k, cy - k)], fill=color, width=2)

def icon_grid(d, x, y, s, color=ACCENT):
    n, g = 3, s / 8.0
    cell = (s - g * (n - 1)) / n
    for r_ in range(n):
        for c_ in range(n):
            x0 = x + c_ * (cell + g)
            y0 = y + r_ * (cell + g)
            d.rounded_rectangle([x0, y0, x0 + cell, y0 + cell], radius=1.5, fill=color)

def icon_plus(d, cx, cy, s, color=ACCENT):
    d.line([(cx - s / 2, cy), (cx + s / 2, cy)], fill=color, width=2)
    d.line([(cx, cy - s / 2), (cx, cy + s / 2)], fill=color, width=2)

def toggle(d, x, y, on):
    w, h = 44, 26
    d.rounded_rectangle([x, y, x + w, y + h], radius=h / 2,
                        fill=GREEN if on else (72, 72, 74))
    cx = x + w - 13 if on else x + 13
    d.ellipse([cx - 10, y + 3, cx + 10, y + 23], fill=(255, 255, 255))

def sec_header(d, x, y, text):
    d.text((x, y), text, font=F_SEC, fill=GRAY)
    return y + 22

def row(d, x, y, w, label, value=None, toggle_on=None, heart=False, check=None, f=None):
    f = f or F_ROW
    tx = x
    if heart:
        icon_heart(d, tx + 9, y + 9, 17)
        tx += 24
    if check is not None:
        if check:
            icon_check_circle(d, tx, y + 1, 16)
        else:
            icon_circle(d, tx, y + 1, 16)
        tx += 24
    d.text((tx, y), label, font=f, fill=WHITE)
    if value is not None:
        rtext(d, x + w - 6, y, value + " ›", F_ROWS, GRAY)
    if toggle_on is not None:
        toggle(d, x + w - 50, y - 5, toggle_on)
    return y + 34

def sep(d, x, y, w):
    d.line([(x, y), (x + w, y)], fill=SEP, width=1)

# ---------- 画布 ----------
MARGIN, GAP = 36, 30
CW = MARGIN * 2 + PW * 4 + GAP * 3
CH = MARGIN + 56 + PH + 116
canvas = Image.new("RGB", (CW, CH), (18, 18, 22))
cd = ImageDraw.Draw(canvas)
cd.text((MARGIN, MARGIN), f"SlidePlay 界面示意 · {SCHEME}（模拟图，最终以真机为准）", font=F_TITLE, fill=WHITE)

# ---------- 1 播放页 ----------
s1 = fake_video(0)
d1 = ImageDraw.Draw(s1)
island(s1)
# 无任何控件，仅示意手势提示（半透明）
hint = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
hd = ImageDraw.Draw(hint)
hd.rounded_rectangle([SW // 2 - 130, SH - 150, SW // 2 + 130, SH - 106],
                     radius=22, fill=(0, 0, 0, 110))
hd.text((SW // 2 - 108, SH - 141), "单击暂停 · 双击两侧 ±10s", font=F_ROWS, fill=(255, 255, 255, 200))
s1 = Image.alpha_composite(s1.convert("RGBA"), hint).convert("RGB")

# ---------- 2 抽屉 ----------
s2 = ImageEnhance.Brightness(fake_video(2)).enhance(0.30)
panel_w = 252
pm = Image.new("L", (panel_w + 60, SH), 0)
ImageDraw.Draw(pm).rounded_rectangle([-60, 0, panel_w, SH - 1], radius=26, fill=255)
panel = Image.new("RGB", (panel_w + 60, SH), (28, 28, 30))
s2.paste(panel, (0, 0), pm)
d2 = ImageDraw.Draw(s2)
d2.text((20, 64), "菜单", font=F_NAV, fill=WHITE)
icon_close(d2, panel_w - 22, 73, 11)
y = 104
x, w = 18, panel_w - 30
y = sec_header(d2, x, y, "当前视频")
d2.text((x, y), "海边日落_4K.mp4", font=F_ROWS, fill=WHITE); y += 24
y = row(d2, x, y, w, "收藏", heart=True, toggle_on=True)
sep(d2, x, y - 6, w); y += 8
y = sec_header(d2, x, y, "播放")
y = row(d2, x, y, w, "播放模式", value="顺序播放")
y = row(d2, x, y, w, "片单", value="全部视频")
y = row(d2, x, y, w, "倍速", value="标准")
y = row(d2, x, y, w, "播完自动下一个", toggle_on=True)
y = row(d2, x, y, w, "循环", value="不循环")
sep(d2, x, y - 6, w); y += 8
y = sec_header(d2, x, y, "画面 / 排序")
y = row(d2, x, y, w, "比例", value="适配")
y = row(d2, x, y, w, "列表排序", value="按文件名")
sep(d2, x, y - 6, w); y += 8
y = sec_header(d2, x, y, "快速选片")
icon_grid(d2, x, y + 1, 16)
d2.text((x + 24, y), "九宫格浏览全部视频", font=F_ROWS, fill=ACCENT); y += 26
d2.rounded_rectangle([x, y, x + w, y + 26], radius=6, fill=(54, 54, 58))
d2.text((x + 8, y + 5), "或搜索视频名", font=F_ROWS, fill=GRAY); y += 36
sep(d2, x, y - 6, w); y += 8
y = sec_header(d2, x, y, "文件夹")
y = row(d2, x, y, w, "视频收藏", check=True)
y = row(d2, x, y, w, "下载", check=False)
icon_plus(d2, x + 9, y + 9, 14)
d2.text((x + 24, y), "添加文件夹…", font=F_ROWS, fill=ACCENT); y += 30
sep(d2, x, y - 6, w); y += 8
y = sec_header(d2, x, y, "隐私")
row(d2, x, y, w, "隐私锁（Face ID）", toggle_on=True)
island(s2)

# ---------- 3 九宫格 ----------
s3 = Image.new("RGB", (SW, SH), (10, 10, 12))
d3 = ImageDraw.Draw(s3)
d3.text((SW // 2 - 52, 62), "选片 · 24 个", font=F_NAV, fill=WHITE)
icon_close(d3, SW - 28, 71, 11)
cols, m, g = 3, 8, 5
cw = (SW - m * 2 - g * (cols - 1)) // cols
chh = int(cw * 16 / 9)
names = ["海边日落_4K", "城市夜景", "冲浪日记", "雪山骑行", "演唱会现场", "深夜厨房",
         "猫咪日常", "公路旅行", "潜水vlog", "街舞练习", "烟花秀", "烘焙教程"]
cell = 0
for r_ in range(4):
    for c_ in range(cols):
        if cell >= len(names):
            break
        x0 = m + c_ * (cw + g)
        y0 = 104 + r_ * (chh + g)
        thumb = fake_video(cell + 1).resize((cw, chh))
        cm = Image.new("L", (cw, chh), 0)
        ImageDraw.Draw(cm).rounded_rectangle([0, 0, cw - 1, chh - 1], radius=8, fill=255)
        s3.paste(thumb, (x0, y0), cm)
        d3 = ImageDraw.Draw(s3)
        bar = Image.new("RGBA", (cw, 20), (0, 0, 0, 120))
        bm = Image.new("L", (cw, 20), 0)
        ImageDraw.Draw(bm).rounded_rectangle([0, 0, cw - 1, 19], radius=0, fill=255)
        s3.paste(bar, (x0, y0 + chh - 20), bm)
        d3.text((x0 + 4, y0 + chh - 17), names[cell], font=F_CELL, fill=WHITE)
        if cell in (1, 5):
            icon_heart(d3, x0 + cw - 14, y0 + 12, 15)
        cell += 1
island(s3)

# ---------- 4 隐私锁 ----------
s4 = Image.new("RGB", (SW, SH), (8, 8, 10))
d4 = ImageDraw.Draw(s4)
# 锁图标
lx, ly = SW // 2, 330
d4.rounded_rectangle([lx - 34, ly, lx + 34, ly + 52], radius=10, fill=(235, 235, 245))
d4.arc([lx - 22, ly - 34, lx + 22, ly + 14], 180, 360, fill=(235, 235, 245), width=9)
d4.ellipse([lx - 5, ly + 18, lx + 5, ly + 30], fill=(8, 8, 10))
d4.text((SW // 2 - 78, ly + 90), "SlidePlay 已上锁", font=F_NAV, fill=WHITE)
# 解锁按钮（主题渐变）
bw2, bh2 = 150, 44
grad_capsule(s4, [SW // 2 - bw2 // 2, ly + 140, SW // 2 + bw2 // 2, ly + 140 + bh2],
             ACCENT, GRAD2, bh2 // 2)
d4.text((SW // 2 - 40, ly + 152), "轻触解锁", font=F_ROW, fill=WHITE)
# Face ID 角标
fx, fy, fl = SW // 2, ly + 260, 26
for sx, sy, a1, a2 in [(-fl, -fl, 180, 270), (fl, -fl, 270, 360),
                       (-fl, fl, 90, 180), (fl, fl, 0, 90)]:
    d4.arc([fx + sx - 14, fy + sy - 14, fx + sx + 14, fy + sy + 14], a1, a2,
           fill=(120, 120, 125), width=4)
d4.line([(fx - 8, fy - 4), (fx - 8, fy + 2)], fill=(120, 120, 125), width=3)
d4.line([(fx + 8, fy - 4), (fx + 8, fy + 2)], fill=(120, 120, 125), width=3)
d4.arc([fx - 9, fy + 1, fx + 9, fy + 15], 20, 160, fill=(120, 120, 125), width=3)
island(s4)

# ---------- 合成 ----------
screens = [s1, s2, s3, s4]
labels = ["① 播放页（零 UI）", "② 侧边菜单", "③ 九宫格选片", "④ 隐私锁"]
captions = [
    "单击暂停 · 双击两侧±10s · 长按2×\n左/右半横拖=亮度/音量 · 底部横拖=进度\n左边缘右滑 → 打开菜单",
    "收藏 / 顺序·随机 / 全部·只看收藏\n倍速 · 循环 · 定时停止 · 排序\n多文件夹切换 · 隐私锁开关",
    "缩略图网格 · 收藏的有红心标记\n点任意一个直接跳过去播",
    "切后台自动上锁\n回来 Face ID 解锁",
]
for i, (sc, lb, cp) in enumerate(zip(screens, labels, captions)):
    x = MARGIN + i * (PW + GAP)
    paste_phone(canvas, sc, x, MARGIN + 56)
    dd = ImageDraw.Draw(canvas)
    dd.text((x + 10, MARGIN + 56 + PH + 14), lb, font=F_LBL, fill=WHITE)
    dd.multiline_text((x + 10, MARGIN + 56 + PH + 46), cp, font=F_CAP, fill=(170, 170, 175), spacing=6)

out = rf"D:\AI\projects\SlidePlay\tools\mockup_{VARIANT}.png"
canvas.save(out, "PNG")
print("saved", out, canvas.size)
