# 青龙客户端 3.0.0

基于青龙原版客户端（Flutter）的修复与适配版，对应服务端 **青龙 2.23.x**。

- 原项目：[qinglong](https://github.com/whyour/qinglong)
- 版本更新通知：https://t.me/qinglongapp
- 下载：[Releases](https://github.com/hicongcn/qinglong_app/releases)

## 下载哪个

| 文件 | 说明 |
|---|---|
| `qinglong_app-3.0.0-arm64-v8a-release.apk` | **手机装这个**（arm64，约 9.3 MB） |
| `qinglong_app-3.0.0-release.apk` | 通用包（含 3 种 ABI，约 24 MB），模拟器 / 多架构用 |
| `qinglong_app-3.0.0-unsigned-arm64-api223.ipa` | iOS 未签名包，需自行签名（TrollStore / AltStore / 证书重签） |

> APK 已签名，可直接安装（签名与历史版本不同，覆盖安装失败时先卸载旧版）。
> IPA 未签名；iOS 部署目标 15.0。

## 这一版做了什么

**适配青龙 2.23**

- 日志删除频率改走 `/api/system/config`；日志 / 脚本 / 配置文件的读取改用 `/detail`（文件名变查询参数）
- 任务搜索参数改 `searchValue`；二次验证登录不再带旧 token
- 参数校验失败时显示具体原因（服务端藏在 `validation.body.message`，原来只显示英文 "Validation failed"）

**iOS 修复**

- Xcode 27 / iOS 27 强制 UIScene 生命周期，补齐场景代理并把插件注册挪到场景引擎上，解决启动黑屏与闪退

**功能对齐面板**

- 仪表盘：8 个数字 + 近 7 日趋势 + 耗时 Top 5 + 次数 Top 5 + 面板状态
- 定时任务：增删改查、启停、置顶、批量、复制、额外调度、允许多个实例、运行/停止、实时日志、队列中状态
- 订阅 / 环境变量 / 配置文件 / 脚本 / 依赖：常规操作齐全；脚本支持编辑历史回滚、重命名、上传下载
- 环境变量：导入、批量导出、批量改名、置顶、拖动排序
- 日志：任务 / 登录 / 系统 / 通知，支持下载与删除
- 系统设置：应用密钥、通知设置、两步验证、面板设置（并发数 / 日志清理频率 / 检查更新）
- 编辑器资源本地化，脚本编辑与配置文件打开即用，不再依赖外网

**其它**

- 移除 VIP 体系，功能全部开放（多账号上限 5、iCloud 备份、FaceID、单实例模式等）
- 设置页与「我的」页版式重做，图标统一
- 实时日志改为增量流式：2 秒轮询只取新增，手动滚动后不再被顶走
- 修复下载文件名（带时间戳，不覆盖）、复制多行带行号、分享在 iPad 上无反应等问题

## 构建

保持原版工具链，**不升级**：

```
Flutter 3.3.10 / Dart 2.18.6
Gradle 6.7 / AGP 4.1.0 / JDK 11 / compileSdk 33
```

```bash
flutter build apk --release --split-debug-info=/tmp/ql-symbols
flutter build apk --release --split-per-abi --split-debug-info=/tmp/ql-symbols
flutter build ipa --release --no-codesign --split-debug-info=/tmp/ql-symbols-ios
flutter test test/
```

> Gradle 6.7 不支持 JDK 17+，`android/gradle.properties` 里要指定 `org.gradle.java.home`。

## 注意

- 使用「应用密钥」登录时，面板给应用的权限不含 `subscriptions` / `dependencies`，相关页面会返回 401，属正常限制，不是 bug。
- 任务「跑到一半自己停了」通常是三种原因：容器重启、单实例模式被下一次调度顶掉、内存不足被 OOMKilled。客户端已提供「允许多个实例」与「任务并发数」两个开关。
- 本仓库只改客户端，不含服务端代码。

## 致谢

- [qinglong](https://github.com/whyour/qinglong) — 服务端与原始客户端
- 所有提交 issue / 反馈问题的使用者

## License

见 [LICENSE](LICENSE)。
