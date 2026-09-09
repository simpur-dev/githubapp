#!/usr/bin/env python3
# R9 阶段1b：页面/私有组件搬家到 5 个 feature HAR + entry 收壳
import os, shutil, subprocess

ROOT = r'E:\githubapp'
ETS = os.path.join(ROOT, 'entry', 'src', 'main', 'ets')
PAGES = os.path.join(ETS, 'pages')
C = os.path.join(ROOT, 'common', 'src', 'main', 'ets')

FEATURES = {
    'feature-auth': ['WelcomePage.ets', 'LoginPage.ets', 'LoginWebPage.ets'],
    'feature-main': ['HomePage.ets', 'SearchPage.ets', 'NotifyPage.ets', 'ReadHistoryPage.ets'],
    'feature-repo': ['RepositoryDetailPage.ets', 'IssueDetailPage.ets', 'PushDetailPage.ets', 'CodeDetailPage.ets',
                     'ReleasePage.ets', 'CommonListPage.ets', 'RepositoryStarPage.ets', 'RepositoryWatcherPage.ets',
                     'RepositoryForkPage.ets'],
    'feature-user': ['UserDetailPage.ets', 'UserFollowerPage.ets', 'UserFollowedPage.ets', 'PersonInfoPage.ets'],
    'feature-misc': ['SettingPage.ets', 'AboutPage.ets', 'HonorPage.ets', 'PhotoPage.ets', 'WebPage.ets', 'CustomPage.ets'],
}

def run(cmd):
    r = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        print('CMD FAIL:', cmd, r.stderr[:300])
    return r.returncode == 0

def gmv(src_rel, dst_rel):
    src = os.path.join(ROOT, src_rel)
    dst = os.path.join(ROOT, dst_rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.exists(src):
        return run('git mv "%s" "%s"' % (src_rel, dst_rel))
    print('MISS:', src_rel)
    return False

moved = []  # (新绝对路径, 来源: 'entry-pages'|'common', 旧相对锚点)

# 1) 平铺页面
for feat, pages in FEATURES.items():
    for p in pages:
        if gmv('entry/src/main/ets/pages/' + p, 'features/%s/src/main/ets/%s' % (feat, p)):
            moved.append(('features/%s/src/main/ets/%s' % (feat, p), 'entry-pages', 'pages/' + p))

# 2) 子目录（保持同名子目录结构）
for feat, sub in [('feature-repo', 'repo'), ('feature-main', 'tabs')]:
    for fn in os.listdir(os.path.join(PAGES, sub)):
        if gmv('entry/src/main/ets/pages/%s/%s' % (sub, fn), 'features/%s/src/main/ets/%s/%s' % (feat, sub, fn)):
            moved.append(('features/%s/src/main/ets/%s/%s' % (feat, sub, fn), 'entry-pages', 'pages/%s/%s' % (sub, fn)))

# 3) common 里的私有组件出库
PRIV = [
    ('common/src/main/ets/ui/components/DrawerHeader.ets', 'feature-main', 'views'),
    ('common/src/main/ets/ui/components/DrawerMenu.ets', 'feature-main', 'views'),
    ('common/src/main/ets/ui/widget/TabIcon.ets', 'feature-main', 'views'),
    ('common/src/main/ets/ui/widget/UserHeadItem.ets', 'feature-main', 'views'),
    ('common/src/main/ets/ui/widget/RepositoryHeader.ets', 'feature-repo', 'views'),
    ('common/src/main/ets/ui/widget/ReleaseItem.ets', 'feature-repo', 'views'),
    ('common/src/main/ets/ui/components/HarmonyLogoMark.ets', 'feature-auth', 'views'),
]
for src_rel, feat, sub in PRIV:
    fn = os.path.basename(src_rel)
    if gmv(src_rel, 'features/%s/src/main/ets/%s/%s' % (feat, sub, fn)):
        moved.append(('features/%s/src/main/ets/%s/%s' % (feat, sub, fn), 'common', 'ui/%s/%s' % (('components' if '/components/' in src_rel.replace('\\','/') else 'widget'), fn)))

# 4) SubListView 在 common 内部挪到 ui/list/
os.makedirs(os.path.join(C, 'ui', 'list'), exist_ok=True)
run('git mv "common/src/main/ets/ui/components/SubListView.ets" "common/src/main/ets/ui/list/SubListView.ets"')

# 5) TagGroup 删除（0 引用）
run('git rm -q "common/src/main/ets/ui/widget/TagGroup.ets"')

# 6) markdown + cpp 归 feature-repo
for fn in ('MarkdownNative.ets', 'MarkdownRenderer.ets'):
    if os.path.exists(os.path.join(ETS, 'markdown', fn)):
        gmv('entry/src/main/ets/markdown/' + fn, 'features/feature-repo/src/main/ets/markdown/' + fn)
        moved.append(('features/feature-repo/src/main/ets/markdown/' + fn, 'entry-pages', 'markdown/' + fn))
if os.path.isdir(os.path.join(ROOT, 'entry', 'src', 'main', 'cpp')):
    run('git mv entry/src/main/cpp features/feature-repo/src/main/cpp')

# 7) 清空目录
for d in ('pages/repo', 'pages/tabs', 'pages/sub', 'markdown'):
    p = os.path.join(ETS, d)
    if os.path.isdir(p) and not os.listdir(p):
        os.rmdir(p)

print('moved files:', len(moved))
print('entry pages left:', os.listdir(PAGES))
