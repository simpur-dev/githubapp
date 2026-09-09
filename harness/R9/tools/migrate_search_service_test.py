import io

p = 'entry/src/ohosTest/ets/test/SearchServiceTest.ets'
s = io.open(p, encoding='utf-8').read()

s = s.replace(
    "    let provider: FakeHttpProvider;\n"
    "    let storage: FakeTokenStorage;\n"
    "    let store: SearchStore;\n"
    "    let service: SearchService;\n"
    "\n"
    "    beforeEach((): void => {\n"
    "      provider = new FakeHttpProvider();\n"
    "      storage = new FakeTokenStorage();\n"
    "      store = new SearchStore();\n"
    "      service = new SearchService(store, PAGE_SIZE);\n",
    "    let provider: FakeHttpProvider;\n"
    "    let storage: FakeTokenStorage;\n"
    "    let service: SearchService;\n"
    "\n"
    "    beforeEach((): void => {\n"
    "      provider = new FakeHttpProvider();\n"
    "      storage = new FakeTokenStorage();\n"
    "      service = new SearchService(PAGE_SIZE);\n")

# store assertions -> res based (stateless service returns page/hasMore)
repls = [
    # search_repo_uses_search_repos_url
    ("      await service.searchRepo('flutter', 'stars', 1);\n\n"
     "      const expected: string = Address.getSearchRepos('flutter', 'stars', 1, PAGE_SIZE);\n"
     "      expect(provider.captured.url).assertEqual(expected);\n"
     "      expect(provider.captured.method).assertEqual('GET');\n"
     "      expect(store.repos.length).assertEqual(3);\n"
     "      expect(store.hasMore).assertTrue();\n"
     "      expect(store.error).assertEqual('');",
     "      const res: SearchRepoResult = await service.searchRepo('flutter', 'stars', 1);\n\n"
     "      const expected: string = Address.getSearchRepos('flutter', 'stars', 1, PAGE_SIZE);\n"
     "      expect(provider.captured.url).assertEqual(expected);\n"
     "      expect(provider.captured.method).assertEqual('GET');\n"
     "      expect(res.data.length).assertEqual(3);\n"
     "      expect(res.hasMore).assertTrue();"),
    # search_user_uses_search_users_url
    ("      await service.searchUser('octocat', null, 1);\n\n"
     "      const expected: string = Address.getSearchUsers('octocat', null, 1, PAGE_SIZE);\n"
     "      expect(provider.captured.url).assertEqual(expected);\n"
     "      expect(provider.captured.method).assertEqual('GET');\n"
     "      expect(store.users.length).assertEqual(2);\n"
     "      expect(store.hasMore).assertFalse();",
     "      const res: SearchUserResult = await service.searchUser('octocat', null, 1);\n\n"
     "      const expected: string = Address.getSearchUsers('octocat', null, 1, PAGE_SIZE);\n"
     "      expect(provider.captured.url).assertEqual(expected);\n"
     "      expect(provider.captured.method).assertEqual('GET');\n"
     "      expect(res.data.length).assertEqual(2);\n"
     "      expect(res.hasMore).assertFalse();"),
    # search_issue_uses_search_issues_url
    ("      await service.searchIssue('bug', null, 1);\n\n"
     "      const expected: string = Address.getSearchIssues('bug', null, 1, PAGE_SIZE);\n"
     "      expect(provider.captured.url).assertEqual(expected);\n"
     "      expect(provider.captured.method).assertEqual('GET');\n"
     "      expect(store.issues.length).assertEqual(3);\n"
     "      expect(store.hasMore).assertTrue();",
     "      const res: SearchIssueResult = await service.searchIssue('bug', null, 1);\n\n"
     "      const expected: string = Address.getSearchIssues('bug', null, 1, PAGE_SIZE);\n"
     "      expect(provider.captured.url).assertEqual(expected);\n"
     "      expect(provider.captured.method).assertEqual('GET');\n"
     "      expect(res.data.length).assertEqual(3);\n"
     "      expect(res.hasMore).assertTrue();"),
    # search_repo_hasMore_true_full_then_false_short
    ("      const r1: SearchRepoResult = await service.searchRepo('q', 'stars', 1);\n"
     "      expect(r1.result).assertTrue();\n"
     "      expect(store.hasMore).assertTrue();\n"
     "      expect(store.repos.length).assertEqual(PAGE_SIZE);\n"
     "      expect(store.page).assertEqual(1);\n\n"
     "      const r2: SearchRepoResult = await service.searchRepo('q', 'stars', 2);\n"
     "      expect(r2.result).assertTrue();\n"
     "      expect(store.hasMore).assertFalse();\n"
     "      expect(store.repos.length).assertEqual(PAGE_SIZE + 1);\n"
     "      expect(store.page).assertEqual(2);",
     "      const r1: SearchRepoResult = await service.searchRepo('q', 'stars', 1);\n"
     "      expect(r1.result).assertTrue();\n"
     "      expect(r1.hasMore).assertTrue();\n"
     "      expect(r1.data.length).assertEqual(PAGE_SIZE);\n"
     "      expect(r1.page).assertEqual(1);\n\n"
     "      const r2: SearchRepoResult = await service.searchRepo('q', 'stars', 2);\n"
     "      expect(r2.result).assertTrue();\n"
     "      expect(r2.hasMore).assertFalse();\n"
     "      expect(r2.data.length).assertEqual(PAGE_SIZE + 1);\n"
     "      expect(r2.page).assertEqual(2);"),
    # search_user_hasMore_paging
    ("      const r1: SearchUserResult = await service.searchUser('u', null, 1);\n"
     "      expect(r1.result).assertTrue();\n"
     "      expect(store.hasMore).assertTrue();\n"
     "      expect(store.users.length).assertEqual(PAGE_SIZE);\n\n"
     "      const r2: SearchUserResult = await service.searchUser('u', null, 2);\n"
     "      expect(r2.result).assertTrue();\n"
     "      expect(store.hasMore).assertFalse();\n"
     "      expect(store.users.length).assertEqual(PAGE_SIZE + 1);",
     "      const r1: SearchUserResult = await service.searchUser('u', null, 1);\n"
     "      expect(r1.result).assertTrue();\n"
     "      expect(r1.hasMore).assertTrue();\n"
     "      expect(r1.data.length).assertEqual(PAGE_SIZE);\n\n"
     "      const r2: SearchUserResult = await service.searchUser('u', null, 2);\n"
     "      expect(r2.result).assertTrue();\n"
     "      expect(r2.hasMore).assertFalse();\n"
     "      expect(r2.data.length).assertEqual(PAGE_SIZE + 1);"),
    # search_issue_hasMore_paging
    ("      const r1: SearchIssueResult = await service.searchIssue('q', null, 1);\n"
     "      expect(r1.result).assertTrue();\n"
     "      expect(store.hasMore).assertTrue();\n"
     "      expect(store.issues.length).assertEqual(PAGE_SIZE);\n\n"
     "      const r2: SearchIssueResult = await service.searchIssue('q', null, 2);\n"
     "      expect(r2.result).assertTrue();\n"
     "      expect(store.hasMore).assertFalse();\n"
     "      expect(store.issues.length).assertEqual(PAGE_SIZE + 1);",
     "      const r1: SearchIssueResult = await service.searchIssue('q', null, 1);\n"
     "      expect(r1.result).assertTrue();\n"
     "      expect(r1.hasMore).assertTrue();\n"
     "      expect(r1.data.length).assertEqual(PAGE_SIZE);\n\n"
     "      const r2: SearchIssueResult = await service.searchIssue('q', null, 2);\n"
     "      expect(r2.result).assertTrue();\n"
     "      expect(r2.hasMore).assertFalse();\n"
     "      expect(r2.data.length).assertEqual(PAGE_SIZE + 1);"),
    # search_repo_failure_sets_error_and_keeps_repos_empty
    ("      const res: SearchRepoResult = await service.searchRepo('q', null, 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(store.repos.length).assertEqual(0);\n"
     "      expect(store.error.length > 0).assertTrue();\n"
     "      expect(store.loading).assertFalse();",
     "      const res: SearchRepoResult = await service.searchRepo('q', null, 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(res.data.length).assertEqual(0);\n"
     "      expect(res.msg.length > 0).assertTrue();"),
    # search_repo_401
    ("      const res: SearchRepoResult = await service.searchRepo('q', null, 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(fired).assertEqual(1);\n"
     "      expect(store.repos.length).assertEqual(0);\n"
     "      expect(store.error.length > 0).assertTrue();",
     "      const res: SearchRepoResult = await service.searchRepo('q', null, 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(fired).assertEqual(1);\n"
     "      expect(res.data.length).assertEqual(0);\n"
     "      expect(res.msg.length > 0).assertTrue();"),
    # search_user_401
    ("      const res: SearchUserResult = await service.searchUser('u', null, 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(fired).assertEqual(1);\n"
     "      expect(store.users.length).assertEqual(0);",
     "      const res: SearchUserResult = await service.searchUser('u', null, 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(fired).assertEqual(1);\n"
     "      expect(res.data.length).assertEqual(0);"),
    # search_issue_401
    ("      const res: SearchIssueResult = await service.searchIssue('q', null, 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(fired).assertEqual(1);\n"
     "      expect(store.issues.length).assertEqual(0);",
     "      const res: SearchIssueResult = await service.searchIssue('q', null, 1);\n\n"
     "      expect(res.result).assertFalse();\n"
     "      expect(res.code).assertEqual(UNAUTHORIZED);\n"
     "      expect(fired).assertEqual(1);\n"
     "      expect(res.data.length).assertEqual(0);"),
]
for old, new in repls:
    if old not in s:
        print('MISSING BLOCK: ' + old[:90].replace('\n', ' | '))
    s = s.replace(old, new)

# rename the store-unit test reference (keep SearchStore unit test, needs a local store)
s = s.replace(
    "    it('store_set_tab_resets_page_and_hasMore', 0, (): void => {\n"
    "      store.applyReposRefresh([buildRepo(1, 'a', 'r')], PAGE_SIZE);",
    "    it('store_set_tab_resets_page_and_hasMore', 0, (): void => {\n"
    "      const store: SearchStore = new SearchStore();\n"
    "      store.applyReposRefresh([buildRepo(1, 'a', 'r')], PAGE_SIZE);")

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('SearchServiceTest migrated')
