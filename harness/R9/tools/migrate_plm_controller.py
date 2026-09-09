import io
import re
import sys

def split_top_args(argstr):
    args = []
    depth = 0
    cur = ''
    in_str = None
    for ch in argstr:
        if in_str:
            cur += ch
            if ch == in_str:
                in_str = None
            continue
        if ch in ('"', "'"):
            in_str = ch
            cur += ch
            continue
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            args.append(cur.strip())
            cur = ''
            continue
        cur += ch
    if cur.strip():
        args.append(cur.strip())
    return args

def migrate(path, decl_map, list_props=True, subview=False):
    """decl_map: {'activityController': ('activityRefreshing','activityLoadingMore','activityNoMore'), ...}"""
    s = io.open(path, encoding='utf-8').read()
    orig = s

    # 1. controller declarations -> boolean states
    for old, (r, l, n) in decl_map.items():
        patterns = [
            ('@State %s: PullLoadMoreController = new PullLoadMoreController();' % old),
            ('@State %s: PullLoadMoreController =\n    new PullLoadMoreController();' % old),
        ]
        repl = ('@State %s: boolean = false;\n  @State %s: boolean = false;\n  @State %s: boolean = false;'
                % (r, l, n))
        for p in patterns:
            s = s.replace(p, repl)

    # 2. API call replacements
    def show_repl(m):
        name = m.group(1)
        if name not in decl_map:
            return m.group(0)
        r, l, n = decl_map[name]
        return '%s = true;\n    %s = false;\n    %s = false;' % (r, l, n)

    def refresh_repl(m):
        name = m.group(1)
        if name not in decl_map:
            return m.group(0)
        r, l, n = decl_map[name]
        args = split_top_args(m.group(2))
        first = args[0] if args else 'false'
        return '%s = false;\n    %s = false;\n    %s = !(%s);' % (r, l, n, first)

    def loadmore_repl(m):
        name = m.group(1)
        if name not in decl_map:
            return m.group(0)
        r, l, n = decl_map[name]
        args = split_top_args(m.group(2))
        first = args[0] if args else 'false'
        return '%s = false;\n    %s = !(%s);' % (l, n, first)

    s = re.sub(r'(\w+)\.showRefreshState\(\)', show_repl, s)
    s = re.sub(r'(\w+)\.refreshComplete\(([^;]*?)\);', refresh_repl, s)
    s = re.sub(r'(\w+)\.loadMoreComplete\(([^;]*?)\);', loadmore_repl, s)

    # 3. imports
    s = s.replace("import { PullLoadMoreList, PullLoadMoreController } from 'common';",
                  "import { PullLoadMoreList } from 'common';")
    s = s.replace("import { PullLoadMoreController } from 'common';", '')
    s = s.replace("import {\n  PullLoadMoreList,\n  PullLoadMoreController,\n} from 'common';",
                  "import {\n  PullLoadMoreList,\n} from 'common';")
    s = s.replace("import {\n  PullLoadMoreController,\n} from 'common';", '')
    s = re.sub(r"import \{\s*PullLoadMoreController,\s*\} from 'common';\n", '', s)

    # 4. PullLoadMoreList / SubListView instantiation: controller: this.X, -> props
    def controller_prop_repl(m):
        expr = m.group(1).strip()
        base = expr.replace('this.', '').strip()
        if base not in decl_map:
            return m.group(0)
        r, l, n = decl_map[base]
        return ('refreshing: this.%s,\n        loadingMore: this.%s,\n        noMore: this.%s,' % (r, l, n))

    if list_props:
        s = re.sub(r'controller:\s*([^,]+),', controller_prop_repl, s)
        # refresh:/loadMore: callback param names -> onRefresh/onLoadMore only inside PullLoadMoreList blocks
        def block_repl(m):
            inner = m.group(1)
            inner2 = re.sub(r'(\n\s*)refresh: \(\)', r'\1onRefresh: ()', inner)
            inner2 = re.sub(r'(\n\s*)loadMore: \(\)', r'\1onLoadMore: ()', inner2)
            return 'PullLoadMoreList({' + inner2 + '})'
        s = re.sub(r'PullLoadMoreList\(\{(.*?)\}\)', block_repl, s, flags=re.S)

    if subview:
        def subview_block_repl(m):
            inner = m.group(1)
            inner2 = re.sub(r'(\n\s*)refresh: \(\)', r'\1onRefresh: ()', inner)
            inner2 = re.sub(r'(\n\s*)loadMore: \(\)', r'\1onLoadMore: ()', inner2)
            return 'SubListView({' + inner2 + '})'
        s = re.sub(r'SubListView\(\{(.*?)\}\)', subview_block_repl, s, flags=re.S)

    if s != orig:
        io.open(path, 'w', encoding='utf-8', newline='\n').write(s)
        print('migrated: ' + path)
    else:
        print('NO CHANGE: ' + path)

if __name__ == '__main__':
    pass
