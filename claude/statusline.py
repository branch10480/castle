#!/usr/bin/env python3
"""Pattern 5: Braille dots progress bar with true color gradient + ccusage cost"""
import json, sys, time, subprocess, os
from datetime import date

data = json.load(sys.stdin)

BRAILLE = ' ⣀⣄⣤⣦⣶⣷⣿'
R = '\033[0m'
DIM = '\033[2m'
CACHE_FILE = '/tmp/ccusage-statusline-cache.json'
CACHE_TTL = 300  # 5 minutes

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

def cost_color(cost):
    if cost < 50:
        return '\033[38;2;100;200;80m'   # green
    elif cost < 100:
        return '\033[38;2;200;200;60m'   # yellow
    else:
        return '\033[38;2;255;100;60m'   # red

def get_ccusage_costs():
    """Get daily/monthly costs from ccusage with file-based cache."""
    # Check cache
    try:
        if os.path.exists(CACHE_FILE):
            mtime = os.path.getmtime(CACHE_FILE)
            if time.time() - mtime < CACHE_TTL:
                with open(CACHE_FILE) as f:
                    return json.load(f)
    except (OSError, json.JSONDecodeError):
        pass

    # Run ccusage daily and monthly in parallel
    today = date.today().strftime('%Y%m%d')
    month_start = date.today().strftime('%Y%m01')
    try:
        p_daily = subprocess.Popen(
            ['ccusage', 'daily', '--json', '--since', today, '--until', today],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        p_monthly = subprocess.Popen(
            ['ccusage', 'monthly', '--json', '--since', month_start],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

        daily_out, _ = p_daily.communicate(timeout=5)
        monthly_out, _ = p_monthly.communicate(timeout=5)

        daily_data = json.loads(daily_out)
        monthly_data = json.loads(monthly_out)

        daily_cost = daily_data.get('daily', [{}])[0].get('totalCost', 0) if daily_data.get('daily') else 0
        monthly_cost = monthly_data.get('monthly', [{}])[0].get('totalCost', 0) if monthly_data.get('monthly') else 0

        result = {'daily': daily_cost, 'monthly': monthly_cost}

        # Write cache
        try:
            with open(CACHE_FILE, 'w') as f:
                json.dump(result, f)
        except OSError:
            pass

        return result
    except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError, OSError):
        # Timeout or ccusage not found - try stale cache
        try:
            if os.path.exists(CACHE_FILE):
                with open(CACHE_FILE) as f:
                    return json.load(f)
        except (OSError, json.JSONDecodeError):
            pass
        return None

# Line 1: usage bars
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
print(f' {DIM}│{R} '.join(parts))

# Line 2: ccusage costs
costs = get_ccusage_costs()
if costs is not None:
    dc = costs['daily']
    mc = costs['monthly']
    line2 = f'{DIM}💰{R} {cost_color(dc)}${dc:.2f}{R} {DIM}today{R} {DIM}│{R} {cost_color(mc)}${mc:.2f}{R} {DIM}/mo{R}'
    print(line2, end='')
