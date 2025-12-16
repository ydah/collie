// Monaco Editor integration

class EditorManager {
  constructor() {
    this.editor = null;
  }

  async initialize(containerId) {
    return new Promise((resolve) => {
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
          value: '// Type your grammar here or load an example\n',
          language: 'yacc',
          theme: 'vs',
          automaticLayout: true,
          minimap: { enabled: false },
          fontSize: 14,
          lineNumbers: 'on',
          scrollBeyondLastLine: false,
          wordWrap: 'on',
          tabSize: 4
        });

        resolve(this.editor);
      });
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
    const markers = diagnostics.map(diag => ({
      severity: this.severityToMonaco(diag.severity),
      startLineNumber: diag.location.line,
      startColumn: diag.location.column,
      endLineNumber: diag.location.line,
      endColumn: diag.location.column + 10,
      message: `[${diag.rule_name}] ${diag.message}`
    }));

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
}
