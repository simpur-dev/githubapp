import io

p = 'entry/src/ohosTest/ets/test/TrendServiceTest.ets'
s = io.open(p, encoding='utf-8').read()

# drop store var; stateless construction
s = s.replace(
    "    let rdb: FakeRdbStore;\n"
    "    let dao: TrendDao;\n"
    "    let store: TrendStore;\n"
    "    let service: TrendService;\n",
    "    let rdb: FakeRdbStore;\n"
    "    let dao: TrendDao;\n"
    "    let service: TrendService;\n")
s = s.replace(
    "      dao = new TrendDao(rdb);\n"
    "      store = new TrendStore();\n"
    "      service = new TrendService(store, dao);\n",
    "      dao = new TrendDao(rdb);\n"
    "      service = new TrendService(dao);\n")

repls = [
    # first_load_success_writes_cache_and_updates_store
    ("      expect(rdb.insertCount).assertEqual(1);\n"
     "      expect(store.list.length).assertEqual(3);\n"
     "      expect(store.since).assertEqual(TREND_SINCE_DAILY);\n"
     "      expect(store.language).assertEqual('go');\n"
     "      expect(store.loading).assertFalse();\n"
     "      expect(store.error).assertEqual('');",
     "      expect(rdb.insertCount).assertEqual(1);"),
    # failure_falls_back_to_cache
    ("      expect(res.data.length).assertEqual(2);\n"
     "      expect(store.list.length).assertEqual(2);\n"
     "      expect(store.since).assertEqual(TREND_SINCE_WEEKLY);\n"
     "      expect(store.language).assertEqual('python');\n"
     "      expect(store.error).assertEqual('');",
     "      expect(res.data.length).assertEqual(2);"),
    # failure_without_cache_sets_error
    ("      expect(res.result).assertFalse();\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(store.list.length).assertEqual(0);\n"
     "      expect(store.error.length > 0).assertTrue();\n"
     "      expect(store.loading).assertFalse();",
     "      expect(res.result).assertFalse();\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(res.data.length).assertEqual(0);\n"
     "      expect(res.msg.length > 0).assertTrue();"),
    # on_401_keeps_cache_visible_after_cache_first_emit
    # 旧断言：缓存先行 emit 后 401，store.list 保持缓存可见（2 条）。
    # 无状态化后等价语义：结果 data 携带已读到的缓存数据（2 条）供 VM 兜底展示。
    ("      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(store.list.length).assertEqual(2);\n"
     "      expect(store.error.length > 0).assertTrue();",
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(res.data.length).assertEqual(2);"),
    # switching_since_and_language_uses_distinct_cache_keys
    ("      await service.fetchTrending(TREND_SINCE_DAILY, 'java');\n"
     "      expect(store.list.length).assertEqual(2);\n\n"
     "      await service.fetchTrending(TREND_SINCE_WEEKLY, 'typescript');\n"
     "      expect(store.list.length).assertEqual(3);",
     "      const dayRes: FetchTrendingResult = await service.fetchTrending(TREND_SINCE_DAILY, 'java');\n"
     "      expect(dayRes.data.length).assertEqual(2);\n\n"
     "      const weekRes: FetchTrendingResult = await service.fetchTrending(TREND_SINCE_WEEKLY, 'typescript');\n"
     "      expect(weekRes.data.length).assertEqual(3);"),
    # store_marks_loading_during_request → 无状态 service 不再持有 loading；改为验证请求完成结果
    ("    it('store_marks_loading_during_request', 0, async (): Promise<void> => {\n"
     "      provider.nextStatus = SUCCESS;\n"
     "      provider.nextBody = '[]';\n\n"
     "      const promise: Promise<FetchTrendingResult> = service.fetchTrending(TREND_SINCE_DAILY,\n"
     "        TREND_LANGUAGE_ALL);\n"
     "      expect(store.loading).assertTrue();\n"
     "      await promise;\n"
     "      expect(store.loading).assertFalse();\n"
     "    });",
     "    it('empty_trend_list_resolves_successfully', 0, async (): Promise<void> => {\n"
     "      provider.nextStatus = SUCCESS;\n"
     "      provider.nextBody = '[]';\n\n"
     "      const res: FetchTrendingResult = await service.fetchTrending(TREND_SINCE_DAILY,\n"
     "        TREND_LANGUAGE_ALL);\n"
     "      expect(res.result).assertTrue();\n"
     "      expect(res.data.length).assertEqual(0);\n"
     "    });"),
]
for old, new in repls:
    if old not in s:
        print('MISSING BLOCK: ' + old[:90].replace('\n', ' | '))
    s = s.replace(old, new)

# remove TrendStore import if now unused
if 'TrendStore' in s and s.count('TrendStore') == 1:
    s = s.replace('  TrendStore,\n', '')

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('TrendServiceTest migrated; TrendStore count =', s.count('TrendStore'))
