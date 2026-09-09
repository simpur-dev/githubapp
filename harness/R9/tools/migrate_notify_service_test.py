import io

p = 'entry/src/ohosTest/ets/test/NotifyServiceTest.ets'
s = io.open(p, encoding='utf-8').read()

# stateless construction; drop store var
s = s.replace(
    "    let provider: FakeHttpProvider;\n"
    "    let storage: FakeTokenStorage;\n"
    "    let store: NotifyStore;\n"
    "    let service: NotifyService;\n",
    "    let provider: FakeHttpProvider;\n"
    "    let storage: FakeTokenStorage;\n"
    "    let service: NotifyService;\n")
s = s.replace(
    "      storage = new FakeTokenStorage();\n"
    "      store = new NotifyStore();\n"
    "      service = new NotifyService(store, PAGE_SIZE);\n",
    "      storage = new FakeTokenStorage();\n"
    "      service = new NotifyService(PAGE_SIZE);\n")

repls = [
    # getNotifications_unread
    ("        expect(store.list.length).assertEqual(PAGE_SIZE);\n"
     "        expect(store.filter).assertEqual(NOTIFY_FILTER_UNREAD);\n"
     "        expect(store.page).assertEqual(1);\n"
     "        expect(store.hasMore).assertTrue();",
     "        expect(res.data.length).assertEqual(PAGE_SIZE);\n"
     "        expect(res.page).assertEqual(1);\n"
     "        expect(res.hasMore).assertTrue();"),
    # getNotifications_participating
    ("        expect(store.filter).assertEqual(NOTIFY_FILTER_PARTICIPATING);\n"
     "        expect(store.list.length).assertEqual(2);\n"
     "        expect(store.hasMore).assertFalse();",
     "        expect(res.data.length).assertEqual(2);\n"
     "        expect(res.hasMore).assertFalse();"),
    # getNotifications_all
    ("        expect(provider.captured.url).assertEqual(expected);\n"
     "        expect(store.filter).assertEqual(NOTIFY_FILTER_ALL);\n"
     "      });",
     "        expect(provider.captured.url).assertEqual(expected);\n"
     "      });"),
    # getNotifications_appends_on_second_page：service 不再拼接两页（拼接归 VM），
    # 等价语义改为断言第二页结果携带 page=2 + hasMore=false。
    ("      await service.getNotifications(NOTIFY_FILTER_UNREAD, 1);\n"
     "      await service.getNotifications(NOTIFY_FILTER_UNREAD, 2);\n\n"
     "      const expectedSecond: string = Address.getNotifications(false, false, 2, PAGE_SIZE);\n"
     "      expect(provider.capturedAll.length).assertEqual(2);\n"
     "      expect(provider.capturedAll[1].url).assertEqual(expectedSecond);\n"
     "      expect(store.list.length).assertEqual(PAGE_SIZE + 2);\n"
     "      expect(store.page).assertEqual(2);\n"
     "      expect(store.hasMore).assertFalse();",
     "      await service.getNotifications(NOTIFY_FILTER_UNREAD, 1);\n"
     "      const r2: FetchNotifyResult = await service.getNotifications(NOTIFY_FILTER_UNREAD, 2);\n\n"
     "      const expectedSecond: string = Address.getNotifications(false, false, 2, PAGE_SIZE);\n"
     "      expect(provider.capturedAll.length).assertEqual(2);\n"
     "      expect(provider.capturedAll[1].url).assertEqual(expectedSecond);\n"
     "      expect(r2.data.length).assertEqual(2);\n"
     "      expect(r2.page).assertEqual(2);\n"
     "      expect(r2.hasMore).assertFalse();"),
    # 401
    ("        const res: FetchNotifyResult = await service.getNotifications(NOTIFY_FILTER_UNREAD, 1);\n"
     "        expect(res.result).assertFalse();\n"
     "        expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "        expect(store.error.length > 0).assertTrue();\n"
     "        expect(store.list.length).assertEqual(0);",
     "        const res: FetchNotifyResult = await service.getNotifications(NOTIFY_FILTER_UNREAD, 1);\n"
     "        expect(res.result).assertFalse();\n"
     "        expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "        expect(res.msg.length > 0).assertTrue();\n"
     "        expect(res.data.length).assertEqual(0);"),
    # network error
    ("      const res: FetchNotifyResult = await service.getNotifications(NOTIFY_FILTER_UNREAD, 1);\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(store.error.length > 0).assertTrue();",
     "      const res: FetchNotifyResult = await service.getNotifications(NOTIFY_FILTER_UNREAD, 1);\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(res.msg.length > 0).assertTrue();"),
    # markAsRead：已读翻转改由 VM 完成；service 断言请求语义（PATCH URL）保持
    ("      expect(provider.capturedAll[provider.capturedAll.length - 1].method).assertEqual('PATCH');\n\n"
     "      let unreadAfter: boolean = true;\n"
     "      for (let i = 0; i < store.list.length; i++) {\n"
     "        if (store.list[i].id === 't1') {\n"
     "          unreadAfter = store.list[i].unread;\n"
     "        }\n"
     "      }\n"
     "      expect(unreadAfter).assertFalse();",
     "      expect(provider.capturedAll[provider.capturedAll.length - 1].method).assertEqual('PATCH');"),
    # store_filter_resets_list_when_filter_changes → 无状态 service 无 filter 状态；
    # 等价改为验证 filter 参数映射到不同请求 URL（setFilter 清空列表语义归 VM）。
    ("    it('store_filter_resets_list_when_filter_changes', 0, async (): Promise<void> => {\n"
     "      provider.pushResponse(SUCCESS, JSON.stringify(buildThreads(PAGE_SIZE)));\n"
     "      await service.getNotifications(NOTIFY_FILTER_UNREAD, 1);\n"
     "      expect(store.list.length).assertEqual(PAGE_SIZE);\n\n"
     "      provider.pushResponse(SUCCESS, JSON.stringify(buildThreads(1)));\n"
     "      await service.getNotifications(NOTIFY_FILTER_ALL, 1);\n"
     "      expect(store.filter).assertEqual(NOTIFY_FILTER_ALL);\n"
     "      expect(store.list.length).assertEqual(1);\n"
     "    });",
     "    it('filter_change_maps_to_new_request_url', 0, async (): Promise<void> => {\n"
     "      provider.pushResponse(SUCCESS, JSON.stringify(buildThreads(PAGE_SIZE)));\n"
     "      await service.getNotifications(NOTIFY_FILTER_UNREAD, 1);\n\n"
     "      provider.pushResponse(SUCCESS, JSON.stringify(buildThreads(1)));\n"
     "      const res: FetchNotifyResult = await service.getNotifications(NOTIFY_FILTER_ALL, 1);\n"
     "      const expectedAll: string = Address.getNotifications(true, false, 1, PAGE_SIZE);\n"
     "      expect(provider.capturedAll[provider.capturedAll.length - 1].url).assertEqual(expectedAll);\n"
     "      expect(res.data.length).assertEqual(1);\n"
     "    });"),
]
for old, new in repls:
    if old not in s:
        print('MISSING BLOCK: ' + old[:90].replace('\n', ' | '))
    s = s.replace(old, new)

# remove unused imports
if s.count('NotifyStore') == 1:
    s = s.replace('  NotifyStore,\n', '')

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('NotifyServiceTest migrated; NotifyStore count =', s.count('NotifyStore'))
