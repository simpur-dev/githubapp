# WelcomePage UI Parity Report

## 1. RN 基准清单

- 源：[WelcomePage.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/WelcomePage.js)
- 顶层容器：`View` 满屏，`backgroundColor = Constant.white (#FFFFFF)`、`styles.mainBox`
- 核心结构：
  ```
  View (mainBox, white)
  └─ View (centered, flex:1)
     ├─ Image welcome.png  width=screenWidth, height=screenHeight, resizeMode=contain
     └─ View (absoluteFull, justifyContent:'flex-end', centered)
        └─ View (150x150 centered)
           └─ LottieView animation-w800-h800.json (autoPlay, loop=false)
  ```
- 样式 token：
  - Color: `Constant.white (#FFFFFF)`
  - Layout: `styles.mainBox` (flex:1)、`styles.centered`、`styles.absoluteFull`
- 交互序列：
  ```
  componentDidMount
    → userActions.initUserInfo()
    → toNext(res)
       setTimeout 3000ms
         → res.result === true ? Actions.reset("MainTabs") : Actions.reset("LoginPage")
  ```

## 2. ArkUI 落地

- 源：[WelcomePage.ets](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/pages/WelcomePage.ets)
- **2026-09-01 用户拍板重构（OH 增强，偏离 RN）**：放弃 RN 端 welcome.png + Lottie 动画视觉，改用 HarmonyOS 系统原生启动窗口同款视觉 —— 屏幕居中 app 图标 + 系统空白背景。
- 顶层 `Stack` 满屏，背景色走资源引用 `$r('app.color.start_window_background')`：base 目录 `#FFFFFF`（浅色）/ dark 目录 `#000000`（深色）由资源限定符自动切换，与 `module.json5` `startWindowBackground` 指向同一资源 → 系统启动窗口 → 本页视觉无缝衔接、跟随系统深浅色模式。
- 居中 `Image($r('app.media.app_icon'))` 尺寸 120，`objectFit(ImageFit.Contain)`。
- 启动延迟：`aboutToAppear` 中 `setTimeout(WELCOME_DELAY_MS = 1000)`，超时后调用 `routeByToken()`：
  - 优先读取 `GlobalAuthStore.token`
  - 其次读取 `AppStorage.get(APP_STORAGE_KEY_TOKEN)` 镜像
  - 最后读取 `Preferences.getString(KEY_USER_TOKEN)`
  - 有 token → `NavigationService.replace(RouteName.Home)`；否则 `NavigationService.replace(RouteName.Login)`
- 测试通道保留：`BOOT_LOGIN_KEY`（强制进登录页）、`BOOT_WELCOME_HOLD_KEY`（停留不跳转，供截图）。
- 颜色：仅资源引用 `$r('app.color.start_window_background')`，无任何 `#xxx` 内联色号。
- 偏差点：
  - RN 端 Lottie 动画 `animation-w800-h800.json` 与 welcome.png 全屏插画均不再使用（用户拍板，OH 增强）。
  - RN 端 token 判断走 `userActions.initUserInfo()`（带网络 self user 校验），OH 端仅做本地 token 存在性判断 + Home 内再异步刷新；行为差异已记录在 [auth.md](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/requirements/auth.md)。

## 3. 截图对照

| RN | ArkUI |
|---|---|
| ![RN WelcomePage](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/WelcomePage.js) （RN 端运行截图待用户回填） | ![OH WelcomePage](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/regression/ui-parity/screenshots/oh_WelcomePage_20260524.png) |

- OH 截图来源：[01_welcome.png](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/regression/reports/M6/device-smoke-20260524-113416/01_welcome.png)
- 实测视觉：白底 + 居中 welcome 插画 + "Welcome" 手写体，与 RN `welcome.png` 一致。
- **2026-09-01 重构后视觉**：居中 app 图标 + 纯色背景（浅色 #FFFFFF / 深色 #000000），与系统启动窗口一致；待真机截图更新（oh_WelcomePage_20260901.png）。

## 4. 差异处理

- 已修齐：
  - 顶层背景使用资源色 `$r('app.color.start_window_background')`，跟随系统深浅色模式；居中渲染 `app_icon`，与系统启动窗口视觉无缝衔接。
  - 1000ms 延迟后路由分流（LoginPage / HomePage），保留原分流逻辑。
- OH 增强（2026-09-01 用户拍板）：
  - 全新系统原生风格：居中图标 + 空白背景，替换 RN 端 welcome.png 插画 + Lottie 动画。
  - 新增 `resources/dark/element/color.json` 深色资源，浅色 `#FFFFFF` / 深色 `#000000` 自动跟随系统模式。
  - 提供 `Preferences` + `AppStorage` 双层 token 兜底读取，避免重复登陆。
- 平台豁免：
  - Lottie 动画：用户拍板移除，不再跟进。
  - `userActions.initUserInfo()` 网络校验：拆分到 HomePage 的 `aboutToAppear` 处再做，避免在 Welcome 阻塞额外网络等待。
