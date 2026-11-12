# 小助手 · iPhone 串流壳（Xcode 工程）

一条命令出 `.ipa`。工程已完整写好，不需要手拼 pbxproj —— 用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成。

---

## 先说清楚这包是什么

`小助手_1.0.9.apk` 里装的是 **Android ELF（arm64-v8a + Bionic）**，三个 native 库 `libUCodev.so` / `libslint_cpp.so` / `libkloader.so` 全段加密，`classes.dex` 只有 64 KB 的 JNI 桥。iOS 要的是 **Mach-O + Apple 签名**。这两样东西之间没有"打包"通道，只有重写。

所以这个工程产出的 IPA 是**串流壳**：iPhone 上全屏显示、直接操作你安卓机上跑着的小助手。它是个真 App（图标、全屏、无浏览器栏、深链跳转），不是网页快捷键。

想要 IPA 里装的就是小助手本体，唯一路径是拿到源码用 iOS SDK 重编；而源码目前锁在加密的 native 层里。

---

## 目录

```
ios-shell/
├── project.yml                        # XcodeGen 工程定义（bundle id / 权限 / ATS / 深链）
├── build.sh                           # 一键出版本
├── Sources/
│   ├── XiaoZhuShouApp.swift           # @main，深链处理
│   ├── ContentView.swift              # 配置页 + 全屏容器 + 顶部唤出工具条
│   ├── WebView.swift                  # WKWebView 封装（target=_blank / 弹窗兜底 / 远程调试）
│   └── Config.swift                   # UserDefaults 持久化
├── Resources/
│   ├── Assets.xcassets/               # AppIcon 1024（无 alpha）+ AccentColor
│   └── Info.plist                     # 由 xcodegen 按 project.yml 生成
└── .github/workflows/build-ipa.yml    # 没 Mac 就在 GitHub Actions 上编
```

生成的 `XiaoZhuShou.xcodeproj` 和 `build/`、`out/` 都不入版本库。

---

## 一、有 Mac：出未签名 IPA（免费 Apple ID 就能装）

```bash
brew install xcodegen          # 只需一次
cd ios-shell
chmod +x build.sh
./build.sh unsigned
```

产出：`out/XiaoZhuShou-1.0.0-unsigned.ipa`

装到 iPhone（不花钱，三选一）：

| 工具 | 平台 | 说明 |
|---|---|---|
| **Sideloadly** | Windows / Mac | 拖入 IPA → 填 Apple ID → Start。最省事 |
| **AltStore / SideStore** | Mac + Windows | 7 天自动续签，不用反复手动装 |
| **爱思助手** | Windows | 国内网络稳，一键自签 |

装完去 iPhone「设置 → 通用 → VPN与设备管理」信任开发者证书。
免费账号签名 **7 天有效**，到期重签一次即可（AltStore 能自动续）。

## 二、有 Mac + 开发者账号：出正式签名 IPA

```bash
./build.sh signed ABCDE12345     # 10 位 Team ID，Xcode 账号页可见
```

或直接数据线装机调试：

```bash
./build.sh run
```

## 三、没有 Mac：用 GitHub Actions 编（推荐给现在的你）

`.github/workflows/build-ipa.yml` 已经配好，macOS runner 免费额度足够。

```bash
cd ios-shell
git init && git add -A
git commit -m "xiaozhushou ios shell"
git remote add origin git@github.com:<你>/xiaozhushou-ios.git
git push -u origin main
```

推送后去仓库 **Actions → build-ipa** 等约 3 分钟 → 页面底部 **Artifacts** 下载 `XiaoZhuShou-ipa`。
解压得到 `.ipa`，再用 **Sideloadly（Windows 版）** 自签装进 iPhone。

> 私有仓库一样能跑，免费额度 2000 分钟/月，这个工程一次约 2~3 分钟。

---

## 用法

首次启动是配置页：

1. **串流地址**（默认）—— 填 ws-scrcpy 的地址，例如 `http://100.64.0.12:8000`
2. **原生 App Scheme** —— 直接唤起 `todesk://` / `rustdesk://` / `sunloginclient://`

连上后：全屏无边框。**从屏幕顶部点一下或下滑**唤出工具条（刷新 / 设置），点画面空白处收起。

深链直接进串流页（可配合 iOS 快捷指令做一键启动）：

```
xiaozhushou://open?url=http://100.64.0.12:8000
```

---

## 改东西

| 想改 | 改哪 |
|---|---|
| bundle id | `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER` |
| 显示名 | `project.yml` → `CFBundleDisplayName` |
| 版本号 | `project.yml` → `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` |
| 图标 | 换掉 `Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`（1024×1024，**不要 alpha 通道**） |
| 允许的 http 域名 | `project.yml` → `NSAppTransportSecurity`（现在全放开，方便内网/Tailscale） |
| 顶部工具条样式 | `Sources/ContentView.swift` → `toolBar` |

改完重新 `./build.sh unsigned`，`xcodegen` 会自动重新生成工程。

---

## 已配好的关键项

- `NSAllowsArbitraryLoads = true` + `NSAllowsLocalNetworking` —— ws-scrcpy 走 http 时不被 ATS 拦
- `NSLocalNetworkUsageDescription` —— 局域网访问的权限文案
- `WKWebView.isInspectable`（iOS 16.4+）—— 可以用 Mac 上 Safari「开发」菜单远程调试页面
- `target="_blank"` / `window.open` 兜底 —— ws-scrcpy 里的新窗口不会白屏
- 全屏 + 隐藏状态栏 + 支持横屏

---

## 常见报错

| 现象 | 处理 |
|---|---|
| `xcodegen: command not found` | `brew install xcodegen`；没 Homebrew 就先装 https://brew.sh |
| `No signing certificate` | 走 `./build.sh unsigned`，别用 signed |
| 装完闪退 | 证书没信任 → 设置里「VPN与设备管理」信任；或重签 |
| 打开是白屏 | 地址没带 `http://`；或页面是 https 而串流是 http（混合内容被拦）→ 串流页也用 http 打开 |
| 画面卡顿 | ws-scrcpy 启动加 `--max-fps 30`，或手机侧关掉动画 |
| 顶部工具条唤不出 | 从**最顶上**（刘海下方）点，热区只有 44pt 高 |
