#!/usr/bin/env python3
# R9 阶段1 一次性迁移工具：生成 common 桶文件 + 重写 import。
import os, re, io, json

ROOT = r'E:\githubapp'
OLD_ROOT = os.path.join(ROOT, 'entry', 'src', 'main', 'ets')
COMMON_ROOT = os.path.join(ROOT, 'common', 'src', 'main', 'ets')
OHOSTEST_ROOT = os.path.join(ROOT, 'entry', 'src', 'ohosTest', 'ets')

# 旧布局 -> 新布局 前缀映射
MOVES = [
    ('net', 'base/net'),
    ('dao', 'base/dao'),
    ('utils', 'base/utils'),
    ('i18n', 'base/i18n'),
    ('ai-debug/Logger.ets', 'base/logger/Logger.ets'),
    ('navigation/NavigationService.ets', 'base/navigation/NavigationService.ets'),
    ('navigation/RouteParamStore.ets', 'base/navigation/RouteParamStore.ets'),
    ('navigation/Routes.ets', 'base/navigation/Routes.ets'),
    ('auth', 'model/auth'),
    ('service', 'model/service'),
    ('store', 'model/store'),
    ('style', 'ui/style'),
    ('theme', 'ui/theme'),
    ('common', 'ui/components'),
    ('widget', 'ui/widget'),
]

def map_old_to_new(old_rel):
    old_rel = old_rel.replace('\\', '/')
    for src, dst in MOVES:
        src_n = src.rstrip('/')
        if old_rel == src or old_rel.startswith(src_n + '/'):
            return os.path.join(COMMON_ROOT, (dst + old_rel[len(src_n):]).replace('/', os.sep))
    return None

def resolve(importer_abs, rel):
    base = os.path.dirname(importer_abs)
    cand = os.path.normpath(os.path.join(base, rel))
    for c in (cand, cand + '.ets'):
        if os.path.isfile(c):
            return c
    return None

def rel_import(from_file, to_file):
    rel = os.path.relpath(to_file, os.path.dirname(from_file)).replace('\\', '/')
    if not rel.startswith('.'):
        rel = './' + rel
    if rel.endswith('.ets'):
        rel = rel[:-4]
    return rel

# ---------- 1. 生成桶文件 ----------
NAME_RE = re.compile(r'^export\s+(?:default\s+)?(?:declare\s+)?(?:abstract\s+)?(?:async\s+)?(?:class|interface|enum|struct|function|const|let|var|type)\s+([A-Za-z0-9_]+)')
barrel_lines = []
seen = {}
conflicts = []
for dirpath, _dirs, files in os.walk(COMMON_ROOT):
    for fn in sorted(files):
        if not fn.endswith('.ets'):
            continue
        fpath = os.path.join(dirpath, fn)
        names = []
        for line in io.open(fpath, encoding='utf-8'):
            m = NAME_RE.match(line.strip())
            if m:
                names.append(m.group(1))
        if not names:
            continue
        rel = os.path.relpath(fpath, COMMON_ROOT).replace('\\', '/')[:-4]
        rel = 'src/main/ets/' + rel  # Index.ets 在模块根，桶内路径要带 src/main/ets 前缀
        dup = [n for n in names if n in seen]
        for d in dup:
            conflicts.append((d, seen[d], rel))
        names = [n for n in names if n not in seen]  # 冲突符号不入桶，后续按编译报错手工归并
        for n in names:
            seen[n] = rel
        if names:
            barrel_lines.append("export { %s } from './%s';" % (', '.join(sorted(set(names))), rel))

barrel = ('// 公共能力层统一出口（R9 阶段1 生成，模块间只允许从这里导入）\n// 禁止跨模块深路径导入。\n\n' + '\n'.join(barrel_lines) + '\n')
io.open(os.path.join(ROOT, 'common', 'Index.ets'), 'w', encoding='utf-8', newline='\n').write(barrel)
print('barrel exports:', len(barrel_lines), 'files;', len(seen), 'symbols')
for c in conflicts:
    print('CONFLICT:', c)

# ---------- 2. 重写 import ----------
IMPORT_RE = re.compile(r"(from\s+')(\.[^']*)(')")
# common 文件新位置 -> 旧位置（相对 OLD_ROOT）
NEW_TO_OLD = []
for src, dst in MOVES:
    if '.' in src:
        NEW_TO_OLD.append((dst, src))
    else:
        NEW_TO_OLD.append((dst, src))
NEW_TO_OLD = [(d.rstrip('/'), s.rstrip('/')) for s, d in MOVES]

def old_rel_of_common_file(fpath):
    rel = os.path.relpath(fpath, COMMON_ROOT).replace('\\', '/')
    for new_prefix, old_prefix in NEW_TO_OLD:
        if rel == new_prefix or rel.startswith(new_prefix + '/'):
            return old_prefix + rel[len(new_prefix):]
    return None

changed = 0
unresolved = []
# 旧布局相对路径集合：搬到 common 的（从新树反推） + 留在 entry 的（磁盘还在的）
old_paths_moved = set()
for dirpath, _dirs, files in os.walk(COMMON_ROOT):
    for fn in files:
        if not fn.endswith('.ets'):
            continue
        rel = os.path.relpath(os.path.join(dirpath, fn), COMMON_ROOT).replace('\\', '/')
        for new_prefix, old_prefix in NEW_TO_OLD:
            if rel == new_prefix or rel.startswith(new_prefix + '/'):
                old_paths_moved.add(old_prefix + rel[len(new_prefix):])

def resolve_old(old_rel_nodot):
    old_rel_nodot = old_rel_nodot.replace('\\', '/')
    for cand in (old_rel_nodot, old_rel_nodot + '.ets'):
        if cand in old_paths_moved:
            return ('common', map_old_to_new(cand))
        if os.path.isfile(os.path.join(OLD_ROOT, cand)):
            return ('entry', os.path.normpath(os.path.join(OLD_ROOT, cand)))
    return (None, None)

for scan_root in (OLD_ROOT, COMMON_ROOT, OHOSTEST_ROOT):
    for dirpath, _dirs, files in os.walk(scan_root):
        if os.sep + 'build' + os.sep in dirpath or os.sep + 'oh_modules' + os.sep in dirpath:
            continue
        for fn in files:
            if not fn.endswith('.ets'):
                continue
            fpath = os.path.join(dirpath, fn)
            text = io.open(fpath, encoding='utf-8').read()
            orig = text
            in_common = fpath.startswith(COMMON_ROOT)
            old_self_rel = old_rel_of_common_file(fpath) if in_common else None

            def repl(m):
                rel = m.group(2)
                if "'lib" in m.group(0):
                    return m.group(0)
                if in_common:
                    if old_self_rel is None:
                        unresolved.append((fpath, rel, 'no-old-self'))
                        return m.group(0)
                    old_target = os.path.normpath(os.path.join(os.path.dirname(old_self_rel), rel)).replace('\\', '/')
                    kind, new_abs = resolve_old(old_target)
                    if kind == 'common':
                        return m.group(1) + rel_import(fpath, new_abs) + m.group(3)
                    if kind == 'entry':
                        unresolved.append((fpath, rel, 'imports-entry-stayput'))
                        return m.group(0)
                    unresolved.append((fpath, rel, 'old-target-missing'))
                    return m.group(0)
                # entry / ohosTest：先按当前磁盘解析（未搬家的文件/ohosTest 内部）
                target = resolve(fpath, rel)
                if target is not None:
                    old_rel = os.path.relpath(target, OLD_ROOT).replace('\\', '/')
                    if map_old_to_new(old_rel) is not None:
                        return m.group(1) + 'common' + m.group(3)
                    return m.group(0)
                # 磁盘解析失败 -> 旧布局回退（指向已搬走目录）
                if OHOSTEST_ROOT in fpath:
                    base_posix = os.path.relpath(fpath, ROOT).replace('\\', '/')
                    norm = os.path.normpath(os.path.join(os.path.dirname(base_posix), rel)).replace('\\', '/')
                    marker = 'main/ets/'
                    idx = norm.find(marker)
                    if idx < 0:
                        unresolved.append((fpath, rel, 'ohostest-no-marker'))
                        return m.group(0)
                    old_target = norm[idx + len(marker):]
                else:
                    old_target = os.path.normpath(os.path.join(os.path.dirname(os.path.relpath(fpath, OLD_ROOT).replace('\\', '/')), rel)).replace('\\', '/')
                kind, _new_abs = resolve_old(old_target)
                if kind == 'common':
                    return m.group(1) + 'common' + m.group(3)
                unresolved.append((fpath, rel, 'fallback-missing'))
                return m.group(0)

            text = IMPORT_RE.sub(repl, text)
            if text != orig:
                io.open(fpath, 'w', encoding='utf-8', newline='\n').write(text)
                changed += 1
print('files with rewritten imports:', changed)
from collections import Counter
kinds = Counter(u[2] for u in unresolved)
print('unresolved summary:', dict(kinds))
for u in unresolved:
    if u[2] != 'old-target-missing':
        print('UNRESOLVED:', u)

