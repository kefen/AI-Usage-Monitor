# AI Usage Monitor

Chrome 0.5.4 adds a Monthly tokens display choice. Only an explicit current-month Token count from the current web account is shown. Unsupported accounts stay unavailable; no local CLI data or estimated counts are substituted.

1. A collapsible Mac-style quota ruler at the bottom of the ChatGPT sidebar.
2. Weekly allowance, plan, credits and reset details from visible official web surfaces. No local helper. Token history is not inferred.
3. Follows visible page changes without recurring usage requests. Checks public GitHub version metadata at most daily and links to newer releases.

Extract the named Chrome ZIP, load the folder at `chrome://extensions` and refresh ChatGPT. Unpacked builds require manual replacement and reload. See the bundled bilingual guide.

中文：下载 Chrome ZIP 解压，加载包含 manifest.json 的目录，然后刷新网页。卡片位于 ChatGPT 左栏底部，无需桌面软件。点击“读取完整用量”可带回同账号的官方读数。发现新版会提示，不会静默安装。
