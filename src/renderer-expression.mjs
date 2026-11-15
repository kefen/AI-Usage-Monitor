export function rendererExpression(widget, state) {
  return `(() => {
    const currentShell = document.querySelector('aside.app-shell-left-panel [data-slate-sidebar-content].sidebar-navigation, aside[data-testid="app-shell-floating-left-panel"] [data-slate-sidebar-content].sidebar-navigation');
    const legacyShell = document.querySelector('main.main-surface') &&
      (document.querySelector('.composer-surface-chrome') || document.querySelector('[role="main"]'));
    const retainedController = window.__localCodexMeter?.controllerId === 'local-codex-sidebar-meter-v1';
    const mainShell = location.protocol === 'app:' && (currentShell || legacyShell || retainedController);
    if (!mainShell) return { mounted:false, reason:'not-main-shell' };
    ${widget}
    window.__localCodexMeter.receive(${JSON.stringify(state)});
    return { mounted:window.__localCodexMeter.mounted(), reason:'sidebar-check' };
  })()`;
}
