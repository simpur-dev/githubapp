# GSYGithubAppOH

## 一款 HarmonyOS ArkUI 原生的开源 GitHub 客户端 App

基于 HarmonyOS ArkUI / Stage Model 开发，功能与 UI 以
[Android Compose 版 GSYGithubAPPCompose](https://github.com/CarGuo/GSYGithubAPPCompose)
为主要对齐目标，覆盖 GitHub 动态、趋势、搜索、仓库详情、Issue、Push、代码浏览、通知、历史、本地缓存、Token 登录和 OAuth WebView 授权登录等场景。

* ### 同款 Android Compose 版 （ https://github.com/CarGuo/GSYGithubAPPCompose ）
* ### 同款 Compose Multiplatform 版 （ https://github.com/CarGuo/GSYGithubAppCMP ）
* ### 同款 Flutter 版 （ https://github.com/CarGuo/gsy_github_app_flutter ）
* ### 同款 Kotlin View 版 （ https://github.com/CarGuo/GSYGithubAppKotlin ）
* ### 同款 ReactNative 版 （ https://github.com/CarGuo/GSYGithubApp ）
* ### 同款 Weex / uni-app 版 （ https://github.com/CarGuo/GSYGithubAppWeex ）

```
项目目标是方便个人日常维护和查阅 GitHub，同时适合 HarmonyOS ArkUI 练手学习。

当前版本以 GSYGithubAPPCompose 为功能、页面和交互验收标准；React Native 版只作为历史参考。
```

## 启动演示

![Welcome to Login](./docs/assets/welcome-login.gif)

## 界面截图

| Dynamic | Search |
| --- | --- |
| ![Dynamic](./docs/assets/screenshot-home-dynamic.png) | ![Search](./docs/assets/screenshot-search.png) |

| Repository Detail | Code Detail |
| --- | --- |
| ![Repository Detail](./docs/assets/screenshot-repo-detail.png) | ![Code Detail](./docs/assets/screenshot-code-detail.png) |

## 编译运行流程

### 环境要求

- DevEco Studio
- HarmonyOS SDK `6.1.0(23)` 或项目当前配置兼容版本
- Node / hvigor 使用 DevEco Studio 自带版本即可
- bundleName：`cn.gsy.githubapp`
- OAuth callback：`gsygithubapp://authed`

> Windows Git Bash 用户：`source scripts/env-win.sh`（scripts/env.sh 为 macOS 版）。
> 无签名验证编译：`hvigorw assembleHap --mode module -p product=unsigned -p buildMode=debug --no-daemon`。

### 一次性签名

HarmonyOS 没有 Android 那种全平台通用 debug keystore。每个开发者都需要用自己的华为开发者账号生成签名材料。

1. 用 DevEco Studio 打开本工程目录。
2. 打开 **File -> Project Structure -> Project -> Signing Configs**，选中 `default`。
3. `Bundle name` 填 `cn.gsy.githubapp`，或改成你自己的 bundleName 并同步修改 [AppScope/app.json5](./AppScope/app.json5)。
4. 勾选 **Automatically generate signature**，登录华为开发者账号后确认。
5. DevEco 会在本机生成 `.p12 / .csr / .cer / .p7b` 等签名材料，并写入 [build-profile.json5](./build-profile.json5)。

### 配置 GitHub OAuth

Token 登录不需要额外配置。若要使用 WebView OAuth 授权登录，需要先在 GitHub 创建 OAuth App：

[注册 GitHub OAuth App](https://github.com/settings/applications/new)

Authorization callback URL 填：

```text
gsygithubapp://authed
```

然后复制本地配置模板：

```sh
cp entry/src/main/resources/rawfile/oauth.local.example.json \
  entry/src/main/resources/rawfile/oauth.local.json
```

把 `oauth.local.json` 改成自己的值：

```json
{
  "client_id": "YOUR_GITHUB_OAUTH_CLIENT_ID",
  "client_secret": "YOUR_GITHUB_OAUTH_CLIENT_SECRET",
  "redirect_uri": "gsygithubapp://authed"
}
```

`oauth.local.json` 已被 [.gitignore](./.gitignore) 忽略，不会入库。

### 运行

- 模拟器：DevEco Studio 顶部选择 HarmonyOS Emulator，运行 `entry`。
- 真机：连接设备并完成签名配置后，运行 `entry`。

命令行打包：

```sh
export DEVECO_HOME="<DevEco Studio Contents path>"
source scripts/env.sh
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

### 测试

```sh
chmod +x harness/regression/run-tests.sh
./harness/regression/run-tests.sh
```

页面回归脚本：

```sh
chmod +x scripts/scenario-tour.sh
./scripts/scenario-tour.sh
```

测试报告和录屏属于本地回归产物，默认不提交。

## 项目结构

```
GSYGithubAppOH/
├── AppScope/                     # 应用级配置
├── common/                       # 公共能力层 HAR
│   └── src/main/ets/
│       ├── base/                 # 网络(HttpManager/Address)/数据库(RDB+Preferences)/工具/日志/i18n/导航服务/启动参数通道
│       ├── model/                # 数据实体 + 无状态 service（网络+缓存取数，只返回数据）
│       └── ui/                   # Theme token/主题管理/通用组件(PullLoadMoreList/弹窗/Toast)/共享widget/markdown文本渲染
├── features/                     # 基础特性层 HAR（每模块 model 调用 + viewmodel + 页面）
│   ├── feature-auth/             # 欢迎页/Token登录/OAuth 授权
│   ├── feature-main/             # 主页框架/动态/趋势/我的/搜索/通知/阅读历史
│   ├── feature-repo/             # 仓库详情/Issue/提交/代码浏览/发布（含 MD4C 原生 Markdown native 模块）
│   ├── feature-user/             # 用户详情/粉丝关注/个人资料
│   └── feature-misc/             # 设置/关于/荣耀/图片/网页/自定义页
├── entry/                        # 产品定制层 HAP 壳：EntryAbility/单根 Navigation 路由表/深链
├── docs/                         # README 展示资源
├── harness/                      # 回归记录、测试策略、架构文档、R9 重构档案
├── scripts/                      # 环境脚本 + 自动回归脚本
└── build-profile.json5
```

依赖方向严格单向：`entry → features → common`。架构规范：
- 状态管理全量 V2（@ComponentV2/@ObservedV2+@Trace/@Local/@Param/@Monitor/@Computed/Repeat）。
- MVVM：页面（View）只做组装，业务状态与编排集中在 ViewModel（@ObservedV2），service 无状态只返回数据；全工程零 AppStorage（启动参数走 BootChannel 单例，登录态走 GlobalAuthStore）。
- 原生组件优先：系统 Refresh 指示器、Navigation 原生标题栏（.title/.menus）与工具栏（.toolbarConfiguration）、SideBarContainer 抽屉、bindMenu 菜单、原生 Radio、SymbolGlyph 系统图标、AlertDialog/ActionSheet/bindSheet 弹层。
- 页面间路由为单根 Navigation + NavDestination；控件 id 保持稳定以支撑 scenario-tour.sh 自动回归。

## 核心能力

- Compose 对齐：Welcome、Login、Home、Search、RepositoryDetail、IssueDetail、PushDetail、CodeDetail、User/Profile、Notification、History。
- 本地缓存：RDB 表用于仓库、README、提交、用户、动态、历史等数据的先读缓存、再网络更新。
- 登录：Personal Access Token 登录、OAuth WebView 登录、`gsygithubapp://authed` 深链回调。
- Web/Markdown：README 和代码详情按 GitHub 内容类型走 WebView 或 ArkUI 文本兜底。
- 自动回归：稳定控件 id、启动参数、scenario tour、Hypium 组件测试。

## 文档入口

- Compose 对照记录：[harness/regression/compose-parity/INDEX.md](./harness/regression/compose-parity/INDEX.md)
- 架构总览：[harness/architecture/overview.md](./harness/architecture/overview.md)
- 测试策略：[harness/testing/strategy.md](./harness/testing/strategy.md)

## 开源协议

本项目基于 [MIT License](./LICENSE) 开源。
