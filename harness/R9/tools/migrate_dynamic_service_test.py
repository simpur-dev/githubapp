import io

p = 'entry/src/ohosTest/ets/test/DynamicServiceTest.ets'
s = io.open(p, encoding='utf-8').read()

s = s.replace("""    let rdb: FakeRdbStore;
    let dao: DynamicDao;
    let store: DynamicStore;
    let service: DynamicService;

    beforeEach((): void => {
      provider = new FakeHttpProvider();
      storage = new FakeTokenStorage();
      rdb = buildStore();
      dao = new DynamicDao(rdb);
      store = new DynamicStore();
      service = new DynamicService(store, dao, PAGE_SIZE);
""",
"""    let rdb: FakeRdbStore;
    let dao: DynamicDao;
    let service: DynamicService;

    beforeEach((): void => {
      provider = new FakeHttpProvider();
      storage = new FakeTokenStorage();
      rdb = buildStore();
      dao = new DynamicDao(rdb);
      service = new DynamicService(dao, PAGE_SIZE);
""")

repls = [
    # first_page_success_writes_cache_and_updates_store
    ("      expect(res.result).assertTrue();\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(res.data.length).assertEqual(PAGE_SIZE);\n"
     "      expect(rdb.insertCount).assertEqual(1);\n"
     "      expect(store.list.length).assertEqual(PAGE_SIZE);\n"
     "      expect(store.page).assertEqual(1);\n"
     "      expect(store.hasMore).assertTrue();\n"
     "      expect(store.loading).assertFalse();\n"
     "      expect(store.error).assertEqual('');",
     "      expect(res.result).assertTrue();\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(res.data.length).assertEqual(PAGE_SIZE);\n"
     "      expect(rdb.insertCount).assertEqual(1);\n"
     "      expect(res.page).assertEqual(1);\n"
     "      expect(res.hasMore).assertTrue();"),
    # failure_falls_back_to_cache_on_first_page
    ("      expect(res.result).assertTrue();\n"
     "      expect(res.fromCache).assertTrue();\n"
     "      expect(res.data.length).assertEqual(2);\n"
     "      expect(store.list.length).assertEqual(2);\n"
     "      expect(store.hasMore).assertFalse();\n"
     "      expect(store.error).assertEqual('');",
     "      expect(res.result).assertTrue();\n"
     "      expect(res.fromCache).assertTrue();\n"
     "      expect(res.data.length).assertEqual(2);\n"
     "      expect(res.hasMore).assertFalse();"),
    # failure_without_cache_sets_error_and_keeps_list_empty
    ("      expect(res.result).assertFalse();\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(store.list.length).assertEqual(0);\n"
     "      expect(store.error.length > 0).assertTrue();\n"
     "      expect(store.loading).assertFalse();",
     "      expect(res.result).assertFalse();\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(res.data.length).assertEqual(0);\n"
     "      expect(res.msg.length > 0).assertTrue();"),
    # hasMore_true_when_full_page_and_false_when_short_page
    ("      const r1: FetchReceivedResult = await service.fetchReceivedEvents(TEST_USER, 1);\n"
     "      expect(r1.result).assertTrue();\n"
     "      expect(store.hasMore).assertTrue();\n"
     "      expect(store.list.length).assertEqual(PAGE_SIZE);\n"
     "      expect(store.page).assertEqual(1);\n\n"
     "      const r2: FetchReceivedResult = await service.fetchReceivedEvents(TEST_USER, 2);\n"
     "      expect(r2.result).assertTrue();\n"
     "      expect(store.hasMore).assertFalse();\n"
     "      expect(store.list.length).assertEqual(PAGE_SIZE + 1);\n"
     "      expect(store.page).assertEqual(2);",
     "      const r1: FetchReceivedResult = await service.fetchReceivedEvents(TEST_USER, 1);\n"
     "      expect(r1.result).assertTrue();\n"
     "      expect(r1.hasMore).assertTrue();\n"
     "      expect(r1.data.length).assertEqual(PAGE_SIZE);\n"
     "      expect(r1.page).assertEqual(1);\n\n"
     "      const r2: FetchReceivedResult = await service.fetchReceivedEvents(TEST_USER, 2);\n"
     "      expect(r2.result).assertTrue();\n"
     "      expect(r2.hasMore).assertFalse();\n"
     "      expect(r2.data.length).assertEqual(1);\n"
     "      expect(r2.page).assertEqual(2);"),
    # second_page_does_not_write_cache
    ("      await service.fetchReceivedEvents(TEST_USER, 1);\n"
     "      const writesAfterFirst: number = rdb.insertCount;\n\n"
     "      await service.fetchReceivedEvents(TEST_USER, 2);\n"
     "      expect(rdb.insertCount).assertEqual(writesAfterFirst);\n"
     "      expect(store.list.length).assertEqual(PAGE_SIZE * 2);",
     "      const r1: FetchReceivedResult = await service.fetchReceivedEvents(TEST_USER, 1);\n"
     "      const writesAfterFirst: number = rdb.insertCount;\n\n"
     "      const r2: FetchReceivedResult = await service.fetchReceivedEvents(TEST_USER, 2);\n"
     "      expect(rdb.insertCount).assertEqual(writesAfterFirst);\n"
     "      // 两页各自返回 PAGE_SIZE 条，拼接归调用方 ViewModel。\n"
     "      expect(r1.data.length + r2.data.length).assertEqual(PAGE_SIZE * 2);"),
    # on_401_publishes_login_expired_and_keeps_list_empty
    ("      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(fired).assertEqual(1);\n"
     "      expect(store.list.length).assertEqual(0);\n"
     "      expect(store.error.length > 0).assertTrue();\n"
     "      expect(store.loading).assertFalse();",
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(fired).assertEqual(1);\n"
     "      expect(res.data.length).assertEqual(0);\n"
     "      expect(res.msg.length > 0).assertTrue();"),
    # on_401_keeps_cache_visible_after_cache_first_emit
    ("      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      expect(store.list.length).assertEqual(2);",
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(res.fromCache).assertFalse();\n"
     "      // 401 时结果携带已读到的首页缓存，供 VM 维持「缓存仍可见」。\n"
     "      expect(res.data.length).assertEqual(2);"),
    # empty_user_does_not_request_network
    ("      const res: FetchReceivedResult = await service.fetchReceivedEvents('', 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(provider.callCount).assertEqual(0);\n"
     "      expect(store.error.length > 0).assertTrue();",
     "      const res: FetchReceivedResult = await service.fetchReceivedEvents('', 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(provider.callCount).assertEqual(0);\n"
     "      expect(res.msg.length > 0).assertTrue();"),
    # fetchUserEvents_first_page_writes_user_event_cache_and_updates_store
    ("        expect(res.result).assertTrue();\n"
     "        expect(res.fromCache).assertFalse();\n"
     "        expect(store.list.length).assertEqual(PAGE_SIZE);\n"
     "        expect(store.page).assertEqual(1);\n"
     "        expect(rdb.rowCountOf(DYN_TABLE_USER_EVENT)).assertEqual(1);\n"
     "        expect(rdb.rowCountOf(DYN_TABLE_RECEIVED)).assertEqual(0);",
     "        expect(res.result).assertTrue();\n"
     "        expect(res.fromCache).assertFalse();\n"
     "        expect(res.data.length).assertEqual(PAGE_SIZE);\n"
     "        expect(res.page).assertEqual(1);\n"
     "        expect(rdb.rowCountOf(DYN_TABLE_USER_EVENT)).assertEqual(1);\n"
     "        expect(rdb.rowCountOf(DYN_TABLE_RECEIVED)).assertEqual(0);"),
    # fetchUserEvents_appends_on_second_page_and_updates_has_more
    ("        const r1: FetchReceivedResult = await service.fetchUserEvents(TEST_USER, 1);\n"
     "        expect(r1.result).assertTrue();\n"
     "        expect(store.hasMore).assertTrue();\n"
     "        expect(store.page).assertEqual(1);\n\n"
     "        const r2: FetchReceivedResult = await service.fetchUserEvents(TEST_USER, 2);\n"
     "        expect(r2.result).assertTrue();\n"
     "        expect(store.hasMore).assertFalse();\n"
     "        expect(store.list.length).assertEqual(PAGE_SIZE + 1);\n"
     "        expect(store.page).assertEqual(2);",
     "        const r1: FetchReceivedResult = await service.fetchUserEvents(TEST_USER, 1);\n"
     "        expect(r1.result).assertTrue();\n"
     "        expect(r1.hasMore).assertTrue();\n"
     "        expect(r1.page).assertEqual(1);\n\n"
     "        const r2: FetchReceivedResult = await service.fetchUserEvents(TEST_USER, 2);\n"
     "        expect(r2.result).assertTrue();\n"
     "        expect(r2.hasMore).assertFalse();\n"
     "        expect(r2.data.length).assertEqual(1);\n"
     "        expect(r2.page).assertEqual(2);"),
    # fetchUserEvents_falls_back_to_user_event_cache_on_network_error
    ("        expect(res.result).assertTrue();\n"
     "        expect(res.fromCache).assertTrue();\n"
     "        expect(store.list.length).assertEqual(2);",
     "        expect(res.result).assertTrue();\n"
     "        expect(res.fromCache).assertTrue();\n"
     "        expect(res.data.length).assertEqual(2);"),
    # fetchUserEvents_on_401
    ("        expect(res.result).assertFalse();\n"
     "        expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "        expect(fired).assertEqual(1);\n"
     "        expect(store.list.length).assertEqual(0);",
     "        expect(res.result).assertFalse();\n"
     "        expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "        expect(fired).assertEqual(1);\n"
     "        expect(res.data.length).assertEqual(0);"),
    # fetchUserEvents_empty_user
    ("        const res: FetchReceivedResult = await service.fetchUserEvents('', 1);\n"
     "        expect(res.result).assertFalse();\n"
     "        expect(provider.callCount).assertEqual(0);\n"
     "        expect(store.error.length > 0).assertTrue();",
     "        const res: FetchReceivedResult = await service.fetchUserEvents('', 1);\n"
     "        expect(res.result).assertFalse();\n"
     "        expect(provider.callCount).assertEqual(0);\n"
     "        expect(res.msg.length > 0).assertTrue();"),
]
for old, new in repls:
    if old not in s:
        print('MISSING BLOCK: ' + old[:90].replace('\n', ' | '))
    s = s.replace(old, new)

if s.count('DynamicStore') == 1:
    s = s.replace("import { DynamicEvent, DynamicStore } from 'common';",
                  "import { DynamicEvent } from 'common';")
# also handle separate import form
if s.count('DynamicStore') == 1 and 'import { DynamicEvent, DynamicStore }' not in s:
    s = s.replace("import { DynamicStore } from 'common';\n", '')

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('DynamicServiceTest migrated; DynamicStore count =', s.count('DynamicStore'))
