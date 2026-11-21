// The installation guide uses the extension's language preference, not account data.
const picker = document.querySelector('#guide-language');
const locales = ['en', 'zh-CN', 'zh-TW'];
function show(mode) {
  const id = locales.includes(mode) ? mode : !/^zh/i.test(navigator.language) ? 'en' : /TW|HK|MO|Hant/i.test(navigator.language) ? 'zh-TW' : 'zh-CN';
  const n = locales.indexOf(id);
  document.documentElement.lang = id;
  document.querySelectorAll('section[lang]').forEach(section => { section.hidden = section.lang !== id; });
  picker.value = locales.includes(mode) ? mode : 'system';
  picker.options[0].text = ['Follow system','跟随系统','跟隨系統'][n];
  document.querySelector('#lang-label').textContent = ['Language','语言','語言'][n];
  document.querySelector('.launch').textContent = ['Open ChatGPT','打开 ChatGPT','開啟 ChatGPT'][n];
  document.querySelector('#disclaimer').textContent = ['Unofficial software. Not affiliated with OpenAI or the Chrome Web Store.','非官方软件，与 OpenAI 及 Chrome 应用商店无隶属关系。','非官方軟體，與 OpenAI 及 Chrome 線上應用程式商店無隸屬關係。'][n];
}
show('system');
chrome.storage.local.get('cqsWebPreferences').then(({cqsWebPreferences}) => show(cqsWebPreferences?.language));
picker.onchange = async () => {
  const language = picker.value; show(language);
  const {cqsWebPreferences} = await chrome.storage.local.get('cqsWebPreferences');
  await chrome.storage.local.set({cqsWebPreferences:{...cqsWebPreferences, language}});
};
