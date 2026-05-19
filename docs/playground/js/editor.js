// Monaco Editor integration

class EditorManager {
  constructor() {
    this.editor = null;
  }

  async initialize(containerId, initialValue) {
    return new Promise((resolve, reject) => {
      require.config({
        paths: {
          vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.44.0/min/vs'
        }
      });

      require(['vs/editor/editor.main'], () => {
        // Register Yacc language
        monaco.languages.register({ id: 'yacc' });

        // Define syntax highlighting
        monaco.languages.setMonarchTokensProvider('yacc', {
          keywords: [
            'token', 'type', 'left', 'right', 'nonassoc', 'prec', 'start',
            'union', 'rule', 'inline'
          ],

          tokenizer: {
            root: [
              // Comments
              [/\/\*/, 'comment', '@comment'],
              [/\/\/.*$/, 'comment'],

              // Directives
              [/%[a-z]+/, {
                cases: {
                  '@keywords': 'keyword',
                  '@default': 'keyword'
                }
              }],

              // Section separator
              [/^%%/, 'keyword.control'],

              // Tokens (uppercase)
              [/\b[A-Z_][A-Z0-9_]*\b/, 'constant'],

              // Nonterminals (lowercase)
              [/\b[a-z_][a-z0-9_]*\b/, 'variable'],

              // Strings
              [/"[^"]*"/, 'string'],
              [/'[^']*'/, 'string'],

              // Actions
              [/\{/, 'delimiter.curly', '@action'],
            ],

            comment: [
              [/\*\//, 'comment', '@pop'],
              [/./, 'comment']
            ],

            action: [
              [/\}/, 'delimiter.curly', '@pop'],
              [/./, 'embedded']
            ]
          }
        });

        // Create editor
        this.editor = monaco.editor.create(document.getElementById(containerId), {
          value: initialValue || '// Type your grammar here or load an example\n',
          language: 'yacc',
          theme: 'vs',
          automaticLayout: true,
          minimap: { enabled: false },
          fontSize: 14,
          lineNumbers: 'on',
          scrollBeyondLastLine: false,
          wordWrap: 'on',
          tabSize: 4,
          renderLineHighlight: 'all'
        });

        resolve(this.editor);
      }, reject);
    });
  }

  getValue() {
    return this.editor.getValue();
  }

  setValue(value) {
    this.editor.setValue(value);
  }

  setMarkers(diagnostics) {
    const model = this.editor.getModel();
    const markers = diagnostics.map(diag => {
      const line = Number(diag.location?.line || 1);
      const column = Number(diag.location?.column || 1);
      const length = Math.max(Number(diag.location?.length || 1), 1);

      return {
        severity: this.severityToMonaco(diag.severity),
        startLineNumber: line,
        startColumn: column,
        endLineNumber: line,
        endColumn: column + length,
        message: `[${diag.rule_name}] ${diag.message}`
      };
    });

    monaco.editor.setModelMarkers(model, 'collie', markers);
  }

  severityToMonaco(severity) {
    switch (severity) {
      case 'error':
        return monaco.MarkerSeverity.Error;
      case 'warning':
        return monaco.MarkerSeverity.Warning;
      case 'convention':
      case 'info':
        return monaco.MarkerSeverity.Info;
      default:
        return monaco.MarkerSeverity.Hint;
    }
  }

  clearMarkers() {
    const model = this.editor.getModel();
    monaco.editor.setModelMarkers(model, 'collie', []);
  }

  reveal(line, column) {
    if (!line || !column) {
      return;
    }

    this.editor.revealPositionInCenter({ lineNumber: line, column });
    this.editor.setPosition({ lineNumber: line, column });
    this.editor.focus();
  }

  onDidChangeContent(callback) {
    this.editor.onDidChangeModelContent(callback);
  }
}
