#!/usr/bin/env python3
"""Pattern 5: Braille dots progress bar with true color gradient"""
import json, sys, time

data = json.load(sys.stdin)

BRAILLE = ' ⣀⣄⣤⣦⣶⣷⣿'
R = '\033[0m'
DIM = '\033[2m'

def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f'\033[38;2;{r};200;80m'
    else:
        g = int(200 - (pct - 50) * 4)
        return f'\033[38;2;255;{max(g, 0)};60m'

def braille_bar(pct, width=8):
    pct = min(max(pct, 0), 100)
    level = pct / 100
    bar = ''
    for i in range(width):
        seg_start = i / width
        seg_end = (i + 1) / width
        if level >= seg_end:
            bar += BRAILLE[7]
        elif level <= seg_start:
            bar += BRAILLE[0]
        else:
            frac = (level - seg_start) / (seg_end - seg_start)
            bar += BRAILLE[min(int(frac * 7), 7)]
    return bar

def time_left(resets_at):
    diff = max(0, resets_at - time.time())
    h, rem = divmod(int(diff), 3600)
    m = rem // 60
    if h >= 24:
        d, h = divmod(h, 24)
        return f'{d}d{h}h'
    return f'{h}h{m:02d}m'

def fmt(label, pct, resets_at=None):
    p = round(pct)
    s = f'{DIM}{label}{R} {gradient(pct)}{braille_bar(pct)}{R} {p}%'
    if resets_at is not None:
        s += f' {DIM}⏳{time_left(resets_at)}{R}'
    return s

model = data.get('model', {}).get('display_name', 'Claude')
parts = []

ctx = data.get('context_window', {}).get('used_percentage')
if ctx is not None:
    parts.append(fmt('ctx', ctx))

five_data = data.get('rate_limits', {}).get('five_hour', {})
five = five_data.get('used_percentage')
if five is not None:
    parts.append(fmt('5h', five, five_data.get('resets_at')))

week_data = data.get('rate_limits', {}).get('seven_day', {})
week = week_data.get('used_percentage')
if week is not None:
    parts.append(fmt('7d', week, week_data.get('resets_at')))

parts.append(model)
print(f' {DIM}│{R} '.join(parts), end='')
