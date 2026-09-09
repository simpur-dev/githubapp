#!/usr/bin/env python3
# R9 阶段1b：为 common + 5 features 生成桶文件 Index.ets
import os, re, io

ROOT = r'E:\githubapp'
MODULES = ['common', 'features/feature-auth', 'features/feature-main', 'features/feature-repo', 'features/feature-user', 'features/feature-misc']
NAME_RE = re.compile(r'^export\s+(?:default\s+)?(?:declare\s+)?(?:abstract\s+)?(?:async\s+)?(?:class|interface|enum|struct|function|const|let|var|type)\s+([A-Za-z0-9_]+)')

for mod in MODULES:
    mod_root = os.path.join(ROOT, mod)
    ets_root = os.path.join(mod_root, 'src', 'main', 'ets')
    lines = []
    seen = {}
    for dirpath, _dirs, files in os.walk(ets_root):
        for fn in sorted(files):
            if not fn.endswith('.ets'):
                continue
            fpath = os.path.join(dirpath, fn)
            names = []
            for line in io.open(fpath, encoding='utf-8'):
                m = NAME_RE.match(line.strip())
                if m:
                    names.append(m.group(1))
            names = [n for n in names if n not in seen]
            for n in names:
                seen[n] = fn
            if names:
                rel = os.path.relpath(fpath, mod_root).replace('\\', '/')[:-4]
                lines.append("export { %s } from './%s';" % (', '.join(sorted(set(names))), rel))
    out = '// %s 统一出口（R9 阶段1b 生成，模块间只允许从这里导入）\n\n' % mod + '\n'.join(lines) + '\n'
    io.open(os.path.join(mod_root, 'Index.ets'), 'w', encoding='utf-8', newline='\n').write(out)
    print(mod, len(lines), 'files', len(seen), 'symbols')
