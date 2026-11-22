# Work Status

## AI Usage Monitor by KEFEN · 最新排期（2026-11-22）

本节为当前排期和发版验收口径；下方历史记录保留，不代表仍待重做。仅服务 Codex、Claude 两个平台。侧边栏回答“还能不能继续用”，独立本地工具回答“两个平台哪个快到限额”；不把两个账户/平台的剩余百分比相加，没有新数据时必须显示上次同步与过期状态。

**已发布基线**：Windows 0.14.1 / macOS 0.6.0-alpha.1。Chrome Web 0.5.5、本地桥接扩展 0.4.1 是两个不同入口，不混用版本号。品牌统一 AI Usage Monitor，保留 by KEFEN。

| Windows / macOS 版本 | 优先级 | 范围和交付物 | Codex 负责 | KEFEN 负责 | 状态和验收 |
|---|---|---|---|---|---|
| 0.14.1 / 0.6.0-alpha.1 | P0 | 周余悬停节奏/重置时间；设置提醒开关与阈值；持久化同窗口去重；导航图标统一 | 原生实现、单元测试、发布及三架构旧版升级 | 日常试用，报告真实通知/休眠/换号问题 | 已发布；默认关闭、阈值 20%；不增加侧边栏文字，不改桌面既有布局。正式源原生验收：Windows run 44980826964，Mac 双架构 run 44981344108 |
| 持续流程，不升软件版本 | P0 | 固定 Windows x64、Mac arm64、Mac x86_64 上一版原生升级验收 | 参数化原生脚本、自动选择上一版、三台干净 VM、失败阻断验收、保留截图和结果 | 发布验收时复核关键原始截图；最终决定对外推广 | 本轮落实；验收结果以 Native release upgrade acceptance / acceptance 为准，不能用构建成功替代 |
| 0.15.0 / 0.7.0-alpha.1 · 数据验证 | P0，下一步 | Claude Code 只读数据源验证；先交付字段支持表和脱敏样本核对，不先改控制台布局 | 分别验证 Win/Mac 可得额度、Token、重置周期、账户标识、刷新条件及授权边界；明确无法读取的字段 | 提供有授权的 Claude Code 环境或脱敏样本，确认优先客户端 | 未开始；无可靠额度/重置/身份则不做 Claude 额度提醒，不使用逆向私有凭据或绕过权限 |
| 0.15.0 / 0.7.0-alpha.1 · 本地 demo → 原生测试包 | P0，依赖数据验证 | 独立本地工具并列查看 Codex/Claude；来源、账户隔离、最近同步、断开/过期态；复用周额度规则 | 先本地 demo，经确认再实现双端原生；无归属读数明确标记；窗口关闭仍可查看最近一次读数但不伪装实时 | 确认 demo 和真实多平台切换流程，测试可用设备 | 未开始；桌面布局变化需先预览确认；只展示可证实字段。先测试包、不自动公开发版 |
| 0.16.0 / 0.8.0-alpha.1 | P1 | 本地近 7/30 天复盘，按平台/模型/项目筛选、导出汇总 | 记录去重、未归因单列、本地汇总、隐私测试；不把 Token 当 API 账单 | 选择最有用的两种维度，用一周样本核对 | 等前版反馈；分项加未归因等于总计，缺失不当作零，导出不含聊天内容 |
| 0.17.0 / 0.9.0-alpha.1（候选） | P2 | Claude 端内轻提示、现有 Chrome 入口协同，不增加第三个平台 | 先验证有稳定、授权的宿主入口；桌面和端内共享设置/去重，不并行重复通知 | 判断是否值得维护、决定做或取消 | 未承诺开发；可关闭、不挤宿主、不重复提醒才做，Chrome 未排确定升级版本 |

**执行顺序**：固定验收流程 → Claude Code 字段/权限验证 → 双平台本地 demo → Win/Mac 原生测试包 → 用户验收 → 发布及正式源三架构升级验收。版本不等于交付日期；无依据不承诺日历日期。若已发布版本出现严重回归，先排 Windows 0.14.2 / Mac 0.6.0-alpha.2 修复，未发现问题不为流程变更空发版本。

### 固定发版验收（每次必须）

1. 发布前：现有构建、单元测试、原生 UI、安装/回滚/生命周期、包摘要与更新签名检查全部保留。使用测试源的候选验证只能算预检。
2. 正式包上传并公开后，签署并提交正式 `docs/updates/v2.json`，自动触发 `.github/workflows/mac-update-delivery.yml`；也可在 Actions 手动重跑。不以 Release 上传完成宣称验收通过。公开更新源必须先存在，因此这是正式源生效后的验收门禁，不能伪称发布前已通过。
3. 自动读取并验签正式源，核对仓库目标版本；从公开 Release 中选择紧邻当前目标的上一版。至少保留当前版和上一版的公开安装包及摘要，不能再“只留最新版”。若旧版已经删除、包不全、签名轮换或源与目标不一致，验收失败并明确处理，不伪造旧版本/更新清单、不绕过验签。
4. 每次开三台新 VM：Windows x64、Mac Apple Silicon、Mac Intel。安装上一版实际公开 Setup/DMG；不使用开发构建、已有安装缓存、个人 Codex 账户或本机实际安装。不改用户现有软件。VM 中只设置与更新无关的首次引导/语言偏好，不预填更新缓存。
5. 必须观察首次启动自动出现的右上角更新图标；通过原生按钮发起下载，核对已校验下载状态、正式 Release 摘要和安装确认框；通过原生确认安装，等待旧进程退出与新进程启动。核对界面、运行程序/App 包均为目标版本，并检查事务完成、设置保留；Mac 还必须有新 App 的启动回执，Windows 还核对快捷方式。
6. 每个架构保存原始截图、`result.json` 和安装诊断：图标自动出现、下载/安装确认、重启后版本号。Actions evidence 保留 90 天，公开前人工打开三份关键截图复核；空白、动画未展开、版本看不清都需重拍，接口成功不算通过。
7. 汇总 `acceptance` 只有三条路径都成功才通过；失败、跳过、取消、超时均不通过。失败后保留证据、暂停宣布发版完成和清理旧包，定位后修复并重跑三条路径，不靠重试接口隐藏问题。该检查是 Actions 验收状态，不声称已配置 GitHub 分支保护或能撤回已经公开的安装包。
8. [Windows 正式源原生基线证据](https://github.com/kefen/AI-Usage-Monitor/actions/runs/44980826964)；[Mac 双芯片正式源原生基线证据](https://github.com/kefen/AI-Usage-Monitor/actions/runs/44981344108)。后续以每次自动验收 run 的结果和截图为准。

### 下一交付物

- [ ] Claude Code 在 Win/Mac 的只读数据可用性验证：字段、来源、周期、身份隔离、刷新及过期行为。
- [ ] 基于可得字段的双平台本地 demo，先让 KEFEN 确认，不提前改桌面已确认布局。
- [ ] demo 通过后开发 0.15.0 / 0.7.0-alpha.1 原生测试包，再进入固定发布验收流程。

### 已确认的额度规则（后续版本继续保持）

1. 侧边栏维持宽度和标签；只在已有“周余”悬停或键盘聚焦时显示距重置时间、节奏，Esc 收起。既有桌面概览布局不随本次流程变更而改动。
2. 只对周期已知的周窗口计算线性参考：已用额度比例减去窗口已过时间比例，大于 5 个百分点为偏快，小于 -5 为较慢，其余平稳；不是耗尽预测。超过 5 分钟未刷新的读数标记待刷新，不告警。
3. 提醒默认关闭，开启后阈值默认 20%，可调 5%—50%。首次新鲜读数小于或等于阈值才提醒；改阈值本身不弹。平台、匿名账户、周窗口、重置时刻共同标记一次提醒；重启、改设置、切页面、恢复后再跌破均不重置；新窗口独立。
4. 身份或周期不能确认、缺少重置时间、数据过期、通知未获授权时不误报；操作系统拒绝通知时不反复申请。Claude 接入必须先证实同样的数据条件，不能拿 Token 活动冒充额度。

## V3 Release (2026-11-17)

- [x] Lock approved visual reference and enumerate prior functional requirements.
- [x] Test and implement update handshake, durable diagnostics and settings preservation (Apple Silicon integration passed; Intel gate pending).
- [x] Desktop plan-family detection with explicit manual override protection (current live client safely returns unknown).
- [x] One shared eleven-metric selection across all user-facing surfaces.
- [x] Reproduce approved Windows UI and installer; verify rendered screenshots.
- [x] Reproduce approved macOS UI; verify native launch/update acknowledgement on both architectures.
- [x] Update browser companion and localized numbered update notes (45 screenshots; real-profile registration pending).
- [x] Complete native tests, packaging, English documentation/screenshots and release audit (105 shared tests; Windows native, 45 browser screenshots, both Mac update integrations).
- [x] Publish verified platform releases, sign and verify live update feed (all six package/source assets matched GitHub digests; live old/current checks, Chinese locale switch and verified Windows download passed).

## Historical Checklist

- [x] Inspect both launchers, document scope and visual contract.
- [ ] Produce shared brand assets and format checks.
- [ ] Redesign Windows startup, preferences, consent, installer and tray.
- [ ] Add matching macOS native application source and build integration.
- [ ] Verify sidebars unchanged, tests, screenshots and packaged candidate.
