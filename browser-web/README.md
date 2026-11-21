# AI Usage Monitor 0.5.4

**Monthly tokens** shows an explicit current-month count only when the signed-in ChatGPT usage page provides it. Otherwise the panel shows that the page does not provide the value. The extension does not read desktop CLI data or estimate a count from quota percentages.

GitHub 网页插件首发版。打开随包的 `guide.html` 查看完整中英文说明。

1. 解压 ZIP 到固定文件夹。
2. Chrome 打开 `chrome://extensions`，启用开发者模式，加载已解压的扩展程序。
3. 选择含 `manifest.json` 的文件夹。
4. 登录 `https://chatgpt.com/`，刷新已打开的页面，展开网页左侧栏。

无需桌面软件、PowerShell、本地辅助程序或手动填写插件 ID。
卡片位于 ChatGPT 左侧栏底部。旧助手面板可以停用，无需重新注册本机程序。

“展示内容”可勾选保存项目。“重新读取”会读取官方用量菜单并还原自己打开的菜单。
要在聊天侧栏查看完整读数，点击“读取完整用量”，在新打开的官方用量页核对账号，点击“确认同账号，带回读数”。结果只返回发起读取的聊天标签页。
数据是 Codex / Work 等共享额度。网页未提供的 Token、5 小时剩余及续费日期不估算。
快速菜单读数 60 秒失效；明确带回的完整读数保留最多 5 分钟。切换账号或刷新标签页后请重新读取。用量只在内存中；扩展仅持久保存展示偏好。

This is a standalone unpacked Chrome extension for the ChatGPT website, not the
legacy native-host side panel. Read `guide.html` for installation, privacy,
unsupported fields, updates and removal. The GitHub build checks public version metadata at most daily and links to newer releases; unpacked installations require manual replacement and reload. Usage follows visible changes on the page, without periodic usage requests.

Developer checks:

```powershell
./runtime/node.exe --test browser-web/test/source.test.mjs
./runtime/node.exe browser-web/test/ui.mjs
./runtime/node.exe browser-web/test/extension.mjs
./browser-web/Build-Test.ps1
```

UI tests require the existing PLAYWRIGHT_MODULE and TEST_BROWSER_PATH settings.
The extension-load test requires Chrome for Testing / Chromium, not a branded
Chrome build that disables command-line extension loading. Its browser profile
is isolated and all website responses are synthetic fixtures.
All screenshots and test pages use synthetic, non-account data.
