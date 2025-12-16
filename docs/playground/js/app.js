// Main playground application

class PlaygroundApp {
  constructor() {
    this.rubyRunner = new RubyRunner();
    this.collieBridge = null;
    this.editorManager = new EditorManager();
    this.currentTab = 'diagnostics';
  }

  async initialize() {
    try {
      document.getElementById('loading').style.display = 'flex';

      await this.rubyRunner.initialize();
      this.collieBridge = new CollieBridge(this.rubyRunner);
      await this.editorManager.initialize('editor');
      await this.loadRulesList();
      this.setupEventListeners();

      document.getElementById('loading').style.display = 'none';
      document.getElementById('main-content').style.display = 'block';
    } catch (error) {
      console.error('Initialization error:', error);
      this.showInitError('Failed to initialize playground: ' + error.message);
    }
  }

  showInitError(message) {
    const loadingContent = document.querySelector('.loading-content');
    loadingContent.innerHTML = `
      <div style="color: #f5222d; max-width: 500px;">
        <h2>Initialization Failed</h2>
        <p>${this.escapeHtml(message)}</p>
        <p style="font-size: 0.9rem; margin-top: 1rem;">
          Please check the browser console for more details.
        </p>
        <button onclick="location.reload()" style="margin-top: 1rem; padding: 0.5rem 1rem; cursor: pointer;">
          Retry
        </button>
      </div>
    `;
  }

  setupEventListeners() {
    // Example selector
    document.getElementById('example-select').addEventListener('change', (e) => {
      const exampleKey = e.target.value;
      if (exampleKey && EXAMPLES[exampleKey]) {
        this.editorManager.setValue(EXAMPLES[exampleKey].code);
      }
    });

    // Lint button
    document.getElementById('lint-btn').addEventListener('click', () => {
      this.handleLint();
    });

    // Format button
    document.getElementById('format-btn').addEventListener('click', () => {
      this.handleFormat();
    });

    // Fix button
    document.getElementById('fix-btn').addEventListener('click', () => {
      this.handleFixAll();
    });

    // Clear button
    document.getElementById('clear-btn').addEventListener('click', () => {
      this.editorManager.setValue('');
      this.editorManager.clearMarkers();
      this.clearOutput();
    });

    // Tab switching
    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        this.switchTab(e.target.dataset.tab);
      });
    });
  }

  async handleLint() {
    const source = this.editorManager.getValue();
    if (!source.trim()) {
      this.showMessage('diagnostics-output', 'Please enter some code first');
      return;
    }

    this.showLoading('diagnostics-output');

    try {
      const diagnostics = await this.collieBridge.lint(source);
      this.displayDiagnostics(diagnostics);
      this.editorManager.setMarkers(diagnostics);
      this.switchTab('diagnostics');
    } catch (error) {
      this.showError('Linting failed: ' + error.message);
    }
  }

  async handleFormat() {
    const source = this.editorManager.getValue();
    if (!source.trim()) {
      this.showMessage('formatted-output', 'Please enter some code first');
      return;
    }

    this.showLoading('formatted-output');

    try {
      const formatted = await this.collieBridge.format(source);
      document.getElementById('formatted-output').textContent = formatted;
      this.switchTab('formatted');
    } catch (error) {
      this.showError('Formatting failed: ' + error.message);
    }
  }

  async handleFixAll() {
    const source = this.editorManager.getValue();
    if (!source.trim()) {
      this.showMessage('diagnostics-output', 'Please enter some code first');
      return;
    }

    try {
      const corrected = await this.collieBridge.autocorrect(source);
      this.editorManager.setValue(corrected);
      await this.handleLint();
    } catch (error) {
      this.showError('Auto-correction failed: ' + error.message);
    }
  }

  displayDiagnostics(diagnostics) {
    const container = document.getElementById('diagnostics-output');

    if (diagnostics.length === 0) {
      container.innerHTML = '<div class="no-offenses">✓ No offenses detected</div>';
      return;
    }

    const html = diagnostics.map(diag => `
      <div class="diagnostic-item ${diag.severity}">
        <div class="diagnostic-location">
          ${diag.location.file}:${diag.location.line}:${diag.location.column}
        </div>
        <div class="diagnostic-message">
          ${this.escapeHtml(diag.message)}
        </div>
        <span class="diagnostic-rule">${diag.rule_name}</span>
        ${diag.autocorrectable ? ' <span class="diagnostic-rule">autocorrectable</span>' : ''}
      </div>
    `).join('');

    container.innerHTML = html;
  }

  async loadRulesList() {
    try {
      const rules = await this.collieBridge.getRules();
      this.displayRules(rules);
    } catch (error) {
      console.error('Failed to load rules:', error);
    }
  }

  displayRules(rules) {
    const container = document.getElementById('rules-output');

    const html = rules.map(rule => `
      <div class="rule-item">
        <div class="rule-header">
          <span class="rule-name">${rule.name}</span>
          <span class="rule-severity ${rule.severity}">${rule.severity}</span>
        </div>
        <div class="rule-description">
          ${this.escapeHtml(rule.description)}
          ${rule.autocorrectable ? ' (autocorrectable)' : ''}
        </div>
      </div>
    `).join('');

    container.innerHTML = html;
  }

  switchTab(tabName) {
    // Update buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });

    // Update content
    document.querySelectorAll('.tab-content').forEach(content => {
      content.classList.toggle('active', content.id === `tab-${tabName}`);
    });

    this.currentTab = tabName;
  }

  showLoading(containerId) {
    document.getElementById(containerId).innerHTML = '<div class="placeholder">Processing...</div>';
  }

  showMessage(containerId, message) {
    document.getElementById(containerId).innerHTML = `<div class="placeholder">${message}</div>`;
  }

  showError(message) {
    alert(message);
  }

  clearOutput() {
    document.getElementById('diagnostics-output').innerHTML = '<div class="placeholder">Click "Lint" to check for issues</div>';
    document.getElementById('formatted-output').textContent = '';
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

// Initialize app when page loads
window.addEventListener('DOMContentLoaded', async () => {
  const app = new PlaygroundApp();
  await app.initialize();
});
