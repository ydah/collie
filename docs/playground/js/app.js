// Main playground application.

class PlaygroundApp {
  constructor() {
    this.rubyRunner = new RubyRunner();
    this.collieBridge = null;
    this.editorManager = new EditorManager();
    this.currentTab = 'diagnostics';
    this.formattedValue = '';
    this.autoLintTimer = null;
    this.isBusy = false;
    this.storageKey = 'collie-playground-source';
    this.shareParam = 'source';
  }

  async initialize() {
    try {
      document.getElementById('loading').style.display = 'flex';

      await this.rubyRunner.initialize();
      this.collieBridge = new CollieBridge(this.rubyRunner);
      await this.editorManager.initialize('editor', this.initialSource());
      this.setupEventListeners();
      await this.loadRulesList();

      document.getElementById('loading').style.display = 'none';
      document.getElementById('main-content').style.display = 'block';
      this.setStatus('Ready');
    } catch (error) {
      console.error('Initialization error:', error);
      this.showInitError(`Failed to initialize playground: ${error.message}`);
    }
  }

  initialSource() {
    const sharedSource = this.sourceFromHash();
    if (sharedSource !== null) {
      return sharedSource;
    }

    const savedSource = this.readStoredSource();
    if (savedSource) {
      return savedSource;
    }

    return EXAMPLES.simple.code;
  }

  showInitError(message) {
    const loadingContent = document.querySelector('.loading-content');
    loadingContent.innerHTML = `
      <div class="init-error">
        <h2>Initialization Failed</h2>
        <p>${this.escapeHtml(message)}</p>
        <p class="init-error-detail">Please check the browser console for more details.</p>
        <button onclick="location.reload()" class="btn btn-primary" type="button">Retry</button>
      </div>
    `;
  }

  setupEventListeners() {
    document.getElementById('example-select').addEventListener('change', event => {
      const exampleKey = event.target.value;
      if (exampleKey && EXAMPLES[exampleKey]) {
        this.editorManager.setValue(EXAMPLES[exampleKey].code);
        this.setStatus(`Loaded ${EXAMPLES[exampleKey].name}`);
      }
    });

    document.getElementById('lint-btn').addEventListener('click', () => {
      this.handleLint();
    });

    document.getElementById('format-btn').addEventListener('click', () => {
      this.handleFormat();
    });

    document.getElementById('fix-btn').addEventListener('click', () => {
      this.handleFixAll();
    });

    document.getElementById('clear-btn').addEventListener('click', () => {
      this.handleClear();
    });

    document.getElementById('apply-format-btn').addEventListener('click', () => {
      this.applyFormatted();
    });

    document.getElementById('copy-format-btn').addEventListener('click', () => {
      this.copyFormatted();
    });

    document.getElementById('share-btn').addEventListener('click', () => {
      this.copyShareUrl();
    });

    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', event => {
        this.switchTab(event.currentTarget.dataset.tab);
      });
    });

    document.getElementById('diagnostics-output').addEventListener('click', event => {
      const item = event.target.closest('.diagnostic-item');
      if (item) {
        this.editorManager.reveal(Number(item.dataset.line), Number(item.dataset.column));
      }
    });

    this.editorManager.onDidChangeContent(() => {
      this.handleEditorChange();
    });
  }

  handleEditorChange() {
    this.saveSource();
    this.clearFormattedOutput();
    this.editorManager.clearMarkers();
    clearTimeout(this.autoLintTimer);

    const source = this.editorManager.getValue();
    if (!source.trim()) {
      this.clearDiagnostics();
      this.setStatus('Editor is empty');
      return;
    }

    this.autoLintTimer = setTimeout(() => {
      if (!this.isBusy) {
        this.handleLint({ silent: true });
      }
    }, 900);
  }

  async handleLint(options = {}) {
    const source = this.editorManager.getValue();
    if (!source.trim()) {
      this.showMessage('diagnostics-output', 'Please enter some code first');
      this.editorManager.clearMarkers();
      this.switchTab('diagnostics');
      return;
    }

    await this.runWithBusy(options.silent ? 'Checking...' : 'Linting...', async () => {
      await this.lintCurrent({ silent: options.silent, switchToDiagnostics: !options.silent });
    });
  }

  async lintCurrent({ silent = false, switchToDiagnostics = true } = {}) {
    if (!silent) {
      this.showLoading('diagnostics-output');
    }

    const response = await this.collieBridge.lint(this.editorManager.getValue());
    const diagnostics = response.diagnostics || [];
    this.displayDiagnostics(diagnostics);
    this.editorManager.setMarkers(diagnostics);

    if (switchToDiagnostics) {
      this.switchTab('diagnostics');
    }

    this.setStatus(this.summaryText(response.summary));
    return response;
  }

  async handleFormat() {
    const source = this.editorManager.getValue();
    if (!source.trim()) {
      this.showMessage('formatted-output', 'Please enter some code first');
      this.switchTab('formatted');
      return;
    }

    await this.runWithBusy('Formatting...', async () => {
      this.showLoading('formatted-output');
      const response = await this.collieBridge.format(source);

      if (!response.ok) {
        const diagnostics = response.diagnostics || [];
        this.displayDiagnostics(diagnostics);
        this.editorManager.setMarkers(diagnostics);
        this.clearFormattedOutput('Format failed');
        this.switchTab('diagnostics');
        this.setStatus('Format failed', 'error');
        return;
      }

      this.formattedValue = response.formatted || '';
      document.getElementById('formatted-output').textContent = this.formattedValue;
      this.updateFormattedActions();
      this.switchTab('formatted');
      this.setStatus(response.changed ? 'Formatted output is ready' : 'Already formatted');
    });
  }

  async handleFixAll() {
    const source = this.editorManager.getValue();
    if (!source.trim()) {
      this.showMessage('diagnostics-output', 'Please enter some code first');
      this.switchTab('diagnostics');
      return;
    }

    await this.runWithBusy('Applying fixes...', async () => {
      const response = await this.collieBridge.autocorrect(source);

      if (!response.ok) {
        const diagnostics = response.diagnostics || [];
        this.displayDiagnostics(diagnostics);
        this.editorManager.setMarkers(diagnostics);
        this.switchTab('diagnostics');
        this.setStatus('Auto-correction failed', 'error');
        return;
      }

      this.editorManager.setValue(response.source || source);
      this.saveSource();
      clearTimeout(this.autoLintTimer);
      await this.lintCurrent({ switchToDiagnostics: true });

      const applied = response.applied || 0;
      this.setStatus(applied === 1 ? 'Applied 1 autocorrection' : `Applied ${applied} autocorrections`);
    });
  }

  handleClear() {
    this.editorManager.setValue('');
    this.editorManager.clearMarkers();
    this.clearOutput();
    this.removeStoredSource();
    this.setStatus('Cleared');
  }

  displayDiagnostics(diagnostics) {
    const container = document.getElementById('diagnostics-output');

    if (diagnostics.length === 0) {
      container.innerHTML = '<div class="no-offenses">No offenses detected</div>';
      return;
    }

    container.innerHTML = diagnostics.map(diag => {
      const line = Number(diag.location?.line || 1);
      const column = Number(diag.location?.column || 1);
      const severity = this.safeClass(diag.severity || 'info');
      const file = this.escapeHtml(diag.location?.file || 'playground.y');
      const ruleName = this.escapeHtml(diag.rule_name || 'Unknown');
      const message = this.escapeHtml(diag.message || '');
      const autocorrectable = diag.autocorrectable ? '<span class="diagnostic-chip">autocorrectable</span>' : '';

      return `
        <button class="diagnostic-item ${severity}" type="button" data-line="${line}" data-column="${column}">
          <span class="diagnostic-location">${file}:${line}:${column}</span>
          <span class="diagnostic-message">${message}</span>
          <span class="diagnostic-chip">${ruleName}</span>
          ${autocorrectable}
        </button>
      `;
    }).join('');
  }

  async loadRulesList() {
    try {
      const rules = await this.collieBridge.getRules();
      this.displayRules(rules);
    } catch (error) {
      console.error('Failed to load rules:', error);
      this.showMessage('rules-output', 'Failed to load rules');
    }
  }

  displayRules(rules) {
    const container = document.getElementById('rules-output');

    container.innerHTML = rules.map(rule => {
      const severity = this.safeClass(rule.severity || 'info');
      const autocorrectable = rule.autocorrectable ? ' (autocorrectable)' : '';

      return `
        <div class="rule-item">
          <div class="rule-header">
            <span class="rule-name">${this.escapeHtml(rule.name)}</span>
            <span class="rule-severity ${severity}">${this.escapeHtml(rule.severity)}</span>
          </div>
          <div class="rule-description">
            ${this.escapeHtml(rule.description || '')}${autocorrectable}
          </div>
        </div>
      `;
    }).join('');
  }

  switchTab(tabName) {
    document.querySelectorAll('.tab-btn').forEach(btn => {
      const isActive = btn.dataset.tab === tabName;
      btn.classList.toggle('active', isActive);
      btn.setAttribute('aria-selected', String(isActive));
    });

    document.querySelectorAll('.tab-content').forEach(content => {
      content.classList.toggle('active', content.id === `tab-${tabName}`);
    });

    this.currentTab = tabName;
  }

  async runWithBusy(label, action) {
    if (this.isBusy) {
      return;
    }

    this.setBusy(true);
    this.setStatus(label, 'muted');

    try {
      await action();
    } catch (error) {
      console.error(error);
      this.setStatus(error.message, 'error');
    } finally {
      this.setBusy(false);
    }
  }

  setBusy(isBusy) {
    this.isBusy = isBusy;
    ['lint-btn', 'format-btn', 'fix-btn', 'clear-btn', 'share-btn'].forEach(id => {
      document.getElementById(id).disabled = isBusy;
    });
    this.updateFormattedActions();
  }

  updateFormattedActions() {
    const disabled = this.isBusy || !this.formattedValue;
    document.getElementById('apply-format-btn').disabled = disabled;
    document.getElementById('copy-format-btn').disabled = disabled;
  }

  setStatus(message, tone = 'default') {
    const status = document.getElementById('operation-status');
    status.textContent = message;
    status.dataset.tone = tone;
  }

  summaryText(summary = {}) {
    if (!summary.total) {
      return 'No offenses detected';
    }

    const bySeverity = summary.by_severity || {};
    const parts = Object.keys(bySeverity)
      .sort()
      .map(severity => `${bySeverity[severity]} ${severity}`);
    const noun = summary.total === 1 ? 'offense' : 'offenses';

    return `${summary.total} ${noun}: ${parts.join(', ')}`;
  }

  showLoading(containerId) {
    document.getElementById(containerId).innerHTML = '<span class="placeholder">Processing...</span>';
  }

  showMessage(containerId, message) {
    document.getElementById(containerId).innerHTML = `<span class="placeholder">${this.escapeHtml(message)}</span>`;
  }

  clearDiagnostics() {
    document.getElementById('diagnostics-output').innerHTML =
      '<div class="placeholder">Click "Lint" to check for issues</div>';
  }

  clearFormattedOutput(message = 'Click "Format" to see formatted output') {
    this.formattedValue = '';
    document.getElementById('formatted-output').innerHTML =
      `<span class="placeholder">${this.escapeHtml(message)}</span>`;
    this.updateFormattedActions();
  }

  clearOutput() {
    this.clearDiagnostics();
    this.clearFormattedOutput();
  }

  applyFormatted() {
    if (!this.formattedValue) {
      return;
    }

    this.editorManager.setValue(this.formattedValue);
    this.saveSource();
    this.setStatus('Formatted output applied');
  }

  async copyFormatted() {
    if (!this.formattedValue) {
      return;
    }

    await this.copyText(this.formattedValue);
    this.setStatus('Formatted output copied');
  }

  async copyShareUrl() {
    const url = new URL(window.location.href);
    url.hash = `${this.shareParam}=${this.encodeSource(this.editorManager.getValue())}`;

    await this.copyText(url.toString());
    this.setStatus('Share URL copied');
  }

  async copyText(text) {
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(text);
        return;
      } catch (error) {
        console.warn('Clipboard API failed, using fallback:', error);
      }
    }

    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.className = 'clipboard-fallback';
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    textarea.remove();
  }

  saveSource() {
    try {
      localStorage.setItem(this.storageKey, this.editorManager.getValue());
    } catch (error) {
      console.warn('Failed to save source:', error);
    }
  }

  readStoredSource() {
    try {
      return localStorage.getItem(this.storageKey);
    } catch (error) {
      console.warn('Failed to read saved source:', error);
      return null;
    }
  }

  removeStoredSource() {
    try {
      localStorage.removeItem(this.storageKey);
    } catch (error) {
      console.warn('Failed to remove saved source:', error);
    }
  }

  sourceFromHash() {
    const hash = window.location.hash.replace(/^#/, '');
    if (!hash) {
      return null;
    }

    const params = new URLSearchParams(hash);
    const encodedSource = params.get(this.shareParam);
    if (!encodedSource) {
      return null;
    }

    try {
      return this.decodeSource(encodedSource);
    } catch (error) {
      console.warn('Failed to decode shared source:', error);
      return null;
    }
  }

  encodeSource(source) {
    const bytes = new TextEncoder().encode(source);
    let binary = '';

    bytes.forEach(byte => {
      binary += String.fromCharCode(byte);
    });

    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  decodeSource(encodedSource) {
    const base64 = encodedSource.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, char => char.charCodeAt(0));

    return new TextDecoder().decode(bytes);
  }

  safeClass(value) {
    return String(value).toLowerCase().replace(/[^a-z0-9_-]/g, '');
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

window.addEventListener('DOMContentLoaded', async () => {
  const app = new PlaygroundApp();
  await app.initialize();
});
