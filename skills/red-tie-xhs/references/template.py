# -*- coding: utf-8 -*-
r"""
RED_TIE 小红书知识卡片模板 · 黑底直出

风格
- 只用黑白灰
- 一张图 一个大标题 一条副标题 若干条内容
- 不用卡片框 不用页码 页脚 系列名
- 留白充足 简约 大气 端庄

使用方式
1 复制本文件到 当前工作目录/xhs/gen_topic.py
2 修改 OUT_DIR
3 修改每张卡的标题 副标题 条目
4 运行 python xhs/gen_topic.py

输出规则
- 图片写到 当前工作目录/xhs/主题英文名/
- 不写用户主目录 不写当前工作目录以外的盘符
- OUT_DIR 默认由 __file__ 推导 从任何位置运行都会写回项目内
"""
import os
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1440
MARGIN = 90
CONTENT_W = W - 2 * MARGIN

BG = (11, 11, 11)
INK = (243, 243, 240)
SUB = (154, 154, 154)
DOT = (110, 110, 110)

TITLE_SIZE = 76
TITLE_LH = 90
SUB_SIZE = 31
ITEM_SIZE = 30
ITEM_LH = 48
ITEM_GAP = 18
CODE_SIZE = 26
CODE_LH = 40


def _first_existing(paths, fallback):
    for path in paths:
        if os.path.exists(path):
            return path
    return fallback


def _font_dirs():
    dirs = []
    env = os.environ.get("RED_TIE_FONT_DIR")
    if env:
        dirs.append(env)
    windir = os.environ.get("WINDIR") or os.environ.get("SystemRoot")
    if windir:
        dirs.append(os.path.join(windir, "Fonts"))
    dirs.extend(["/mnt/c/Windows/Fonts",
                 "/usr/share/fonts/truetype/noto",
                 os.path.expanduser("~/.local/share/fonts")])
    return dirs


_FONT_DIRS = _font_dirs()
MSYHBD = _first_existing([os.path.join(d, n) for d in _FONT_DIRS
                          for n in ("msyhbd.ttc", "NotoSansCJK-Bold.ttc",
                                    "NotoSansCJKsc-Bold.otf")],
                         None)
MSYH = _first_existing([os.path.join(d, n) for d in _FONT_DIRS
                        for n in ("msyh.ttc", "NotoSansCJK-Regular.ttc",
                                  "NotoSansCJKsc-Regular.otf")],
                       None)
CONSOLA = _first_existing([os.path.join(d, n) for d in _FONT_DIRS
                           for n in ("consola.ttf", "DejaVuSansMono.ttf")],
                          None)

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
_DEFAULT_OUT = os.path.join(_BASE_DIR, "topic")
OUT_DIR = os.environ.get("RED_TIE_OUT", _DEFAULT_OUT)
os.makedirs(OUT_DIR, exist_ok=True)


def font(path, size):
    if not MSYH:
        raise SystemExit(
            "未找到中文字体：安装 Noto Sans CJK，或设置 RED_TIE_FONT_DIR 指向字体目录")
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.truetype(MSYH, size)


def is_cjk(ch):
    return ("\u4e00" <= ch <= "\u9fff" or "\u3000" <= ch <= "\u303f"
            or "\uff00" <= ch <= "\uffef")


def text_width(draw, text, ft):
    if not text:
        return 0
    return draw.textbbox((0, 0), text, font=ft)[2]


def wrap_lines(draw, text, ft, max_width):
    word_chars = set("_+#./:&*<>()[]{}%-")
    tokens = []
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch.isascii() and (ch.isalnum() or ch in word_chars):
            j = i
            while (j < n and text[j].isascii()
                   and (text[j].isalnum() or text[j] in word_chars)):
                j += 1
            tokens.append(text[i:j])
            i = j
        else:
            tokens.append(ch)
            i += 1

    result = []
    current = ""
    for tok in tokens:
        if tok == " ":
            if current:
                current += tok
            continue
        candidate = current + tok
        if current and text_width(draw, candidate, ft) > max_width:
            result.append(current.rstrip())
            current = tok
        else:
            current = candidate
        while text_width(draw, current, ft) > max_width and len(current) > 1:
            prefix = ""
            for ch in current:
                if prefix and text_width(draw, prefix + ch, ft) > max_width:
                    break
                prefix += ch
            if not prefix:
                prefix = current[0]
            result.append(prefix)
            current = current[len(prefix):]
    if current.strip():
        result.append(current.rstrip())
    return result


def new_page():
    img = Image.new("RGB", (W, H), BG)
    return img, ImageDraw.Draw(img)


def title_block(draw, lines, y):
    ft = font(MSYHBD, TITLE_SIZE)
    for line in lines:
        draw.text((MARGIN, y), line, font=ft, fill=INK)
        y += TITLE_LH
    return y


def subtitle(draw, text, y):
    draw.text((MARGIN, y), text, font=font(MSYH, SUB_SIZE), fill=SUB)
    return y + 46


def bullets(draw, items, y):
    ft = font(MSYH, ITEM_SIZE)
    for item in items:
        draw.ellipse([MARGIN, y + 22, MARGIN + 10, y + 32], fill=DOT)
        for line in wrap_lines(draw, item, ft, CONTENT_W - 46):
            draw.text((MARGIN + 46, y), line, font=ft, fill=INK)
            y += ITEM_LH
        y += ITEM_GAP
    return y - ITEM_GAP


def code_lines(draw, label, lines, y):
    draw.text((MARGIN, y), label, font=font(MSYH, 23), fill=SUB)
    y += 34
    for line in lines:
        ft = font(MSYH, CODE_SIZE - 1) if any(is_cjk(c) for c in line) else font(CONSOLA, CODE_SIZE)
        draw.text((MARGIN, y), line, font=ft, fill=INK)
        y += CODE_LH
    return y + 28


def render_bullets(out_name, title_lines, sub, items):
    img, draw = new_page()
    title_h = len(title_lines) * TITLE_LH
    sub_h = (24 + 46) if sub else 0

    prepared = []
    for item in items:
        marker = None
        if item[:2] in ("× ", "√ "):
            marker = item[0]
            item = item[2:]
        prepared.append((marker, wrap_lines(draw, item, font(MSYH, ITEM_SIZE), CONTENT_W - 46)))

    items_h = (sum(len(w) * ITEM_LH for _, w in prepared)
               + ITEM_GAP * (len(prepared) - 1))
    total = title_h + sub_h + (40 + items_h if items else 0)
    y = max(170, (H - total) // 2)

    y = title_block(draw, title_lines, y)
    if sub:
        y += 24
        y = subtitle(draw, sub, y)
    if items:
        y += 40
        for marker, w in prepared:
            if marker:
                draw.text((MARGIN + 4, y - 2), marker,
                          font=font(MSYHBD, ITEM_SIZE), fill=SUB)
            else:
                draw.ellipse([MARGIN, y + 22, MARGIN + 10, y + 32], fill=DOT)
            for line in w:
                draw.text((MARGIN + 46, y), line, font=font(MSYH, ITEM_SIZE), fill=INK)
                y += ITEM_LH
            y += ITEM_GAP

    img.save(os.path.join(OUT_DIR, out_name))


def render_code(out_name, title_lines, sub, blocks, note=None):
    img, draw = new_page()
    title_h = len(title_lines) * TITLE_LH
    sub_h = (24 + 46) if sub else 0

    blocks_h = 0
    for label, lines in blocks:
        blocks_h += 34 + len(lines) * CODE_LH + 28

    note_lines = wrap_lines(draw, note, font(MSYH, ITEM_SIZE), CONTENT_W - 46) if note else []
    note_h = (24 + len(note_lines) * ITEM_LH + 18) if note else 0

    total = title_h + sub_h + (34 + blocks_h) + note_h
    y = max(140, (H - total) // 2)

    y = title_block(draw, title_lines, y)
    if sub:
        y += 24
        y = subtitle(draw, sub, y)
    y += 34
    for label, lines in blocks:
        y = code_lines(draw, label, lines, y)
    if note:
        y += 24
        draw.ellipse([MARGIN, y + 22, MARGIN + 10, y + 32], fill=DOT)
        for line in note_lines:
            draw.text((MARGIN + 46, y), line, font=font(MSYH, ITEM_SIZE), fill=INK)
            y += ITEM_LH

    img.save(os.path.join(OUT_DIR, out_name))


# ------------------------- 以下替换为实际内容 -------------------------

def main():
    render_bullets(
        "00_cover.png",
        ["主题名称", "一句核心结论"],
        "一句副标题",
        ["第一条干货", "第二条干货", "第三条干货", "第四条干货"],
    )
    render_bullets(
        "01_core.png",
        ["核心差异"],
        "一句判断标准",
        ["事实一", "事实二", "事实三", "事实四", "事实五"],
    )
    render_bullets(
        "02_what.png",
        ["它是什么"],
        "一句主结论",
        ["01 第一步", "02 第二步", "03 第三步", "04 第四步", "05 第五步"],
    )
    render_bullets(
        "03_key.png",
        ["常见误解", "与准确结论"],
        "哪些成立 哪些不成立",
        ["× 一条常见误解", "√ 一条准确结论", "× 第二条误解", "√ 第二条准确结论"],
    )
    render_code(
        "04_example.png",
        ["一个具体例子"],
        "代码 命令 或案例",
        [("示例 A", ["// 第一段", "code();"]),
         ("示例 B", ["// 第二段", "code();"])],
        "一句最容易踩的坑",
    )
    render_bullets(
        "05_summary.png",
        ["速查"],
        "一句话加若干易错点",
        ["01 易错点一", "02 易错点二", "03 易错点三",
         "04 易错点四", "05 易错点五"],
    )
    print("ALL_DONE", OUT_DIR)


if __name__ == "__main__":
    main()
