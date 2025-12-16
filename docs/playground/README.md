# Collie Playground

An interactive web-based playground for trying out Collie, the linter and formatter for Lrama Style BNF grammar files.

## Features

- Interactive Monaco Editor (same as VS Code)
- Real-time linting with all 18 built-in rules
- Grammar formatting
- Auto-fix functionality
- Yacc/Bison/Lrama syntax highlighting
- Pre-loaded example grammar files
- Runs completely in the browser using Ruby.wasm

## How It Works

The playground uses [Ruby.wasm](https://github.com/ruby/ruby.wasm) to run Ruby code directly in your browser. All Collie functionality (parsing, linting, formatting) executes client-side - your code never leaves your browser.

### Architecture

```
Browser
├── Monaco Editor (UI)
├── Ruby.wasm (Ruby runtime)
├── collie-bundle.rb (All Collie code)
└── JavaScript bridge (UI ↔ Ruby)
```

## Local Development

### Prerequisites

- Ruby 3.2 or higher
- Modern web browser

### Setup

1. Generate the Collie bundle:
```bash
ruby build-collie-bundle.rb
```

2. Serve the playground locally:
```bash
# Using Ruby
ruby -run -ehttpd . -p 8000

# Using Python
python3 -m http.server 8000

# Using Node.js (if you have http-server installed)
npx http-server -p 8000
```

3. Open http://localhost:8000/ in your browser

### Rebuilding the Bundle

Whenever Collie's code changes, rebuild the bundle:

```bash
ruby build-collie-bundle.rb
```

## Deployment

The playground is automatically deployed to GitHub Pages via GitHub Actions when changes are pushed to the main branch.

### GitHub Actions Workflow

See `.github/workflows/deploy-playground.yml` for the deployment configuration.

The workflow:
1. Checks out the repository
2. Sets up Ruby
3. Builds the Collie bundle
4. Deploys to GitHub Pages

### Accessing the Deployed Playground

Once deployed, the playground will be available at:
```
https://ydah.github.io/collie/playground/
```

## Files

- `index.html` - Main HTML page
- `css/styles.css` - Stylesheet
- `js/app.js` - Main application logic
- `js/editor.js` - Monaco Editor integration
- `js/ruby-runner.js` - Ruby.wasm wrapper
- `js/collie-bridge.js` - JavaScript ↔ Ruby bridge
- `js/examples.js` - Example grammar files
- `collie-bundle.rb` - Bundled Collie code (generated)
- `build-collie-bundle.rb` - Bundle generation script

## Limitations

- First load may be slow (Ruby.wasm is ~30MB)
- Large grammar files (>10,000 lines) may be slow
- Some Ruby features may not work in WebAssembly

## Troubleshooting

### "Failed to initialize Ruby.wasm"

- Ensure you have a stable internet connection (Ruby.wasm is loaded from CDN)
- Try refreshing the page
- Clear browser cache

### "Collie bundle not found"

- Run `ruby build-collie-bundle.rb` to generate the bundle
- Ensure `collie-bundle.rb` exists in the playground directory

### Linting/Formatting doesn't work

- Check browser console for JavaScript errors
- Ensure the bundle was generated correctly
- Try with a simple example first

## Contributing

To add new features or fix bugs:

1. Make changes to the playground files
2. Test locally using a local web server
3. If you changed Collie code, rebuild the bundle
4. Submit a pull request

## License

MIT License - Same as Collie
