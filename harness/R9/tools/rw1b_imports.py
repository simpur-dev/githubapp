#!/usr/bin/env python3
# R9 阶段1b：全工程 import 重写
# - features/ 内文件：先按当前磁盘解析，失败则按旧位置（entry/pages 或 common）解析
# - entry 壳 + ohosTest：'common' 导入按符号归属拆分到 feature 包；相对路径磁盘/旧布局两级解析
import os, re, io

ROOT = r'E:\githubapp'
OLD_ROOT = os.path.join(ROOT, 'entry', 'src', 'main', 'ets')
COMMON_ROOT = os.path.join(ROOT, 'common', 'src', 'main', 'ets')
OHOSTEST_ROOT = os.path.join(ROOT, 'entry', 'src', 'ohosTest', 'ets')
FEATURES = ['feature-auth', 'feature-main', 'feature-repo', 'feature-user', 'feature-misc']
FEAT_ROOTS = {f: os.path.join(ROOT, 'features', f, 'src', 'main', 'ets') for f in FEATURES}

MODULES = {'common': COMMON_ROOT}
for f in FEATURES:
    MODULES[f] = FEAT_ROOTS[f]

# ---- 1a 的旧布局映射（common 内部） ----
MOVES_1A = [
    ('net', 'base/net'), ('dao', 'base/dao'), ('utils', 'base/utils'), ('i18n', 'base/i18n'),
    ('ai-debug/Logger.ets', 'base/logger/Logger.ets'),
    ('navigation/NavigationService.ets', 'base/navigation/NavigationService.ets'),
    ('navigation/RouteParamStore.ets', 'base/navigation/RouteParamStore.ets'),
    ('navigation/Routes.ets', 'base/navigation/Routes.ets'),
    ('auth', 'model/auth'), ('service', 'model/service'), ('store', 'model/store'),
    ('style', 'ui/style'), ('theme', 'ui/theme'), ('common', 'ui/components'), ('widget', 'ui/widget'),
]

def map_1a(old_rel):
    old_rel = old_rel.replace('\\', '/')
    for src, dst in MOVES_1A:
        src_n = src.rstrip('/')
        if old_rel == src_n or old_rel.startswith(src_n + '/'):
            return os.path.join(COMMON_ROOT, (dst + old_rel[len(src_n):]).replace('/', os.sep))
    return None

# ---- 页面旧位置 -> feature 映射 ----
PAGE_TO_FEAT = {
    'WelcomePage.ets': 'feature-auth', 'LoginPage.ets': 'feature-auth', 'LoginWebPage.ets': 'feature-auth',
    'HomePage.ets': 'feature-main', 'SearchPage.ets': 'feature-main', 'NotifyPage.ets': 'feature-main',
    'ReadHistoryPage.ets': 'feature-main',
    'tabs/DynamicTabPage.ets': 'feature-main', 'tabs/TrendTabPage.ets': 'feature-main', 'tabs/MyTabPage.ets': 'feature-main',
    'RepositoryDetailPage.ets': 'feature-repo', 'IssueDetailPage.ets': 'feature-repo', 'PushDetailPage.ets': 'feature-repo',
    'CodeDetailPage.ets': 'feature-repo', 'ReleasePage.ets': 'feature-repo', 'CommonListPage.ets': 'feature-repo',
    'RepositoryStarPage.ets': 'feature-repo', 'RepositoryWatcherPage.ets': 'feature-repo', 'RepositoryForkPage.ets': 'feature-repo',
    'repo/ActivityTab.ets': 'feature-repo', 'repo/FilesTab.ets': 'feature-repo', 'repo/IssueTab.ets': 'feature-repo', 'repo/ReadmeTab.ets': 'feature-repo',
    'markdown/MarkdownNative.ets': 'feature-repo', 'markdown/MarkdownRenderer.ets': 'feature-repo',
    'UserDetailPage.ets': 'feature-user', 'UserFollowerPage.ets': 'feature-user', 'UserFollowedPage.ets': 'feature-user',
    'PersonInfoPage.ets': 'feature-user',
    'SettingPage.ets': 'feature-misc', 'AboutPage.ets': 'feature-misc', 'HonorPage.ets': 'feature-misc',
    'PhotoPage.ets': 'feature-misc', 'WebPage.ets': 'feature-misc', 'CustomPage.ets': 'feature-misc',
}
COMMON_PRIV_OLD = {  # 从 common 出库的组件：旧 ui 相对路径 -> (feature, 新文件名)
    'ui/components/DrawerHeader.ets': 'feature-main', 'ui/components/DrawerMenu.ets': 'feature-main',
    'ui/widget/TabIcon.ets': 'feature-main', 'ui/widget/UserHeadItem.ets': 'feature-main',
    'ui/widget/RepositoryHeader.ets': 'feature-repo', 'ui/widget/ReleaseItem.ets': 'feature-repo',
    'ui/components/HarmonyLogoMark.ets': 'feature-auth',
}

# ---- 磁盘文件索引 ----
disk_files = set()
for root in [OLD_ROOT, COMMON_ROOT, OHOSTEST_ROOT] + list(FEAT_ROOTS.values()):
    for dp, _d, fs in os.walk(root):
        for fn in fs:
            if fn.endswith('.ets'):
                disk_files.add(os.path.normpath(os.path.join(dp, fn)))

def module_of(abs_path):
    abs_path = os.path.normpath(abs_path)
    if abs_path.startswith(COMMON_ROOT):
        return 'common'
    for f, r in FEAT_ROOTS.items():
        if abs_path.startswith(r):
            return f
    return 'entry'

def resolve_disk(importer, rel):
    cand = os.path.normpath(os.path.join(os.path.dirname(importer), rel))
    for c in (cand, cand + '.ets'):
        if c in disk_files:
            return c
    return None

def rel_import(from_file, to_file):
    rel = os.path.relpath(to_file, os.path.dirname(from_file)).replace('\\', '/')
    if not rel.startswith('.'):
        rel = './' + rel
    if rel.endswith('.ets'):
        rel = rel[:-4]
    return rel

def old_anchor_for(fpath):
    """features 内文件的旧位置锚点（相对 OLD_ROOT 或 COMMON_ROOT 的旧相对路径）"""
    rel = os.path.relpath(fpath, ROOT).replace('\\', '/')
    m = re.search(r'features/([^/]+)/src/main/ets/(.+)', rel)
    if not m:
        return ('entry', None)
    feat, inner = m.group(1), m.group(2)
    fn = os.path.basename(inner)
    if inner.startswith('views/'):
        old = [k for k, v in COMMON_PRIV_OLD.items() if v == feat and os.path.basename(k) == fn]
        return ('common', old[0] if old else None)
    # entry/pages 来源
    if inner in PAGE_TO_FEAT:
        return ('entry', 'pages/' + inner)
    if inner.startswith('repo/'):
        return ('entry', 'pages/' + inner)
    if inner.startswith('tabs/'):
        return ('entry', 'pages/' + inner)
    if inner.startswith('markdown/'):
        return ('entry', inner)
    return ('entry', 'pages/' + inner)

# ---- 符号 -> 包 映射（从 6 个桶文件解析） ----
sym_pkg = {}
for mod, mod_root in [('common', os.path.join(ROOT, 'common'))] + [(f, os.path.join(ROOT, 'features', f)) for f in FEATURES]:
    idx = os.path.join(mod_root, 'Index.ets')
    for line in io.open(idx, encoding='utf-8'):
        m = re.match(r"export \{([^}]*)\} from", line.strip())
        if m:
            for n in m.group(1).split(','):
                sym_pkg[n.strip()] = mod

IMPORT_RE = re.compile(r"(import\s+(?:type\s+)?\{[^}]*\}\s*from\s+')([^']+)(';)")
changed = 0
violations = []
missing = []

def classify_old(kind, anchor, rel, importer):
    """按旧锚点解析目标；返回 ('common'|feature|'entry'|None, abs|old_rel)"""
    if kind == 'common':
        t = os.path.normpath(os.path.join(os.path.dirname(anchor), rel)).replace('\\', '/')
        if not t.endswith('.ets'):
            t = t + '.ets'
        # common 出库组件？
        if t in COMMON_PRIV_OLD:
            return (COMMON_PRIV_OLD[t], None)
        if t[:-4] in COMMON_PRIV_OLD:
            return (COMMON_PRIV_OLD[t[:-4]], None)
        # 1a 搬到 common 的？
        abs_new = map_1a(t)
        if abs_new is not None:
            return ('common', abs_new)
        abs_new = map_1a(t[:-4])
        if abs_new is not None:
            return ('common', abs_new)
        # common 里本来就有的（1a 后已在 COMMON_ROOT，相对形状同旧）
        for c in (os.path.normpath(os.path.join(COMMON_ROOT, t)), os.path.normpath(os.path.join(COMMON_ROOT, t[:-4]))):
            if c in disk_files:
                return ('common', c)
        return (None, None)
    else:
        t = os.path.normpath(os.path.join(os.path.dirname(anchor), rel)).replace('\\', '/')
        t = t.replace('\\', '/')
        if not t.endswith('.ets'):
            t = t + '.ets'
        base = os.path.basename(t)
        # 指向别的页面/tab/markdown？
        if t in PAGE_TO_FEAT:
            return (PAGE_TO_FEAT[t], t)
        # SubListView？
        if base == 'SubListView.ets':
            return ('common', None)
        # 1a 搬 common 的？
        abs_new = map_1a(t)
        if abs_new is not None:
            return ('common', abs_new)
        # 留在 entry 的（Index/AppNavigator/entryability）
        if os.path.isfile(os.path.join(OLD_ROOT, t)) or os.path.isfile(os.path.join(OLD_ROOT, t + '.ets')):
            return ('entry', None)
        return (None, None)

viol_files = 0
for scan_root in [OLD_ROOT, COMMON_ROOT, OHOSTEST_ROOT] + list(FEAT_ROOTS.values()):
    for dp, _d, fs in os.walk(scan_root):
        for fn in fs:
            if not fn.endswith('.ets'):
                continue
            fpath = os.path.normpath(os.path.join(dp, fn))
            text = io.open(fpath, encoding='utf-8').read()
            orig = text
            in_feature = fpath.startswith(os.path.join(ROOT, 'features'))

            def repl(m):
                head, spec, tail = m.group(1), m.group(2), m.group(3)
                if spec == 'common' and not in_feature:
                    # 拆分符号归属
                    inner = re.search(r"\{([^}]*)\}", head).group(1)
                    names = [n.strip() for n in inner.split(',') if n.strip()]
                    groups = {}
                    unknown = []
                    for n in names:
                        pkg = sym_pkg.get(n)
                        if pkg is None:
                            unknown.append(n)
                            pkg = 'common'
                        groups.setdefault(pkg, []).append(n)
                    if unknown:
                        missing.append((fpath, unknown))
                    if set(groups.keys()) == {'common'}:
                        return m.group(0)
                    parts = []
                    if 'common' in groups:
                        parts.append("import { %s } from 'common';" % ', '.join(groups['common']))
                    for pkg in sorted(groups):
                        if pkg == 'common':
                            continue
                        parts.append("import { %s } from '%s';" % (', '.join(groups[pkg]), pkg))
                    return '\n'.join(parts)
                if spec.startswith('.'):
                    hit = resolve_disk(fpath, spec)
                    if hit is not None:
                        mod = module_of(hit)
                        self_mod = module_of(fpath)
                        if mod == self_mod:
                            return head + rel_import(fpath, hit) + tail
                        if self_mod == 'entry' or self_mod == 'common':
                            violations.append((fpath, spec, mod))
                            return head + mod + tail
                        # feature -> feature / feature -> entry 违规
                        violations.append((fpath, spec, mod))
                        return head + ("'%s'" % mod if mod != 'entry' else "'%s'" % mod) + tail
                    # 旧布局解析
                    if in_feature:
                        kind, anchor = old_anchor_for(fpath)
                        if anchor is None:
                            missing.append((fpath, spec))
                            return m.group(0)
                        pkg, abs_or_rel = classify_old(kind, anchor, spec, fpath)
                        if pkg is None:
                            missing.append((fpath, spec))
                            return m.group(0)
                        if pkg == 'entry':
                            violations.append((fpath, spec, 'entry'))
                            return m.group(0)
                        if pkg == 'common' and abs_or_rel is not None:
                            return head + rel_import(fpath, abs_or_rel) + tail
                        return head + pkg + tail
                    # entry 壳 / ohosTest：旧布局（相对 OLD_ROOT）
                    if OHOSTEST_ROOT in fpath:
                        base_posix = os.path.relpath(fpath, ROOT).replace('\\', '/')
                        norm = os.path.normpath(os.path.join(os.path.dirname(base_posix), spec)).replace('\\', '/')
                        idx = norm.find('main/ets/')
                        if idx < 0:
                            missing.append((fpath, spec))
                            return m.group(0)
                        t = norm[idx + len('main/ets/'):]
                    else:
                        t = os.path.normpath(os.path.join(os.path.dirname(os.path.relpath(fpath, OLD_ROOT).replace('\\', '/')), spec)).replace('\\', '/')
                    t = t.replace('\\', '/')
                    if not t.endswith('.ets'):
                        t = t + '.ets'
                    hit_page = None
                    for cand in (t, t[6:] if t.startswith('pages/') else None):
                        if cand and cand in PAGE_TO_FEAT:
                            hit_page = cand
                            break
                    if hit_page is not None:
                        return head + ("'%s'" % PAGE_TO_FEAT[hit_page]) + tail
                    pkg, _x = classify_old('entry', t if '/' in t else t, '.', fpath) if False else (None, None)
                    abs_new = map_1a(t)
                    if abs_new is not None:
                        return head + 'common' + tail
                    if t.startswith('ui/components/') or t.startswith('ui/widget/'):
                        # common 出库组件或仍在 common 的组件
                        if t in COMMON_PRIV_OLD:
                            return head + COMMON_PRIV_OLD[t] + tail
                        return head + 'common' + tail
                    missing.append((fpath, spec))
                    return m.group(0)
                return m.group(0)

            text = IMPORT_RE.sub(repl, text)
            if text != orig:
                io.open(fpath, 'w', encoding='utf-8', newline='\n').write(text)
                changed += 1

print('changed files:', changed)
print('violations:', len(violations))
for v in violations[:20]:
    print('VIOLATION:', v)
print('missing:', len(missing))
for mm in missing[:30]:
    print('MISSING:', mm)
