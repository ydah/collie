// Bridge between JavaScript and the Ruby playground API.

class CollieBridge {
  constructor(rubyRunner) {
    this.ruby = rubyRunner;
    this.filename = 'playground.y';
  }

  async lint(source) {
    return this.call('lint', { source, filename: this.filename });
  }

  async format(source) {
    return this.call('format', { source, filename: this.filename });
  }

  async autocorrect(source) {
    return this.call('autocorrect', { source, filename: this.filename });
  }

  async getRules() {
    const response = await this.call('rules');
    return response.rules;
  }

  async call(method, payload = {}) {
    const encodedPayload = this.encodePayload(payload);
    const rubyCode = `
      require 'base64'
      require 'json'

      payload_json = Base64.decode64('${encodedPayload}').force_encoding('UTF-8')
      payload = JSON.parse(payload_json)
      Collie::Playground.${method}(payload)
    `;

    const result = await this.ruby.eval(rubyCode);
    return JSON.parse(result.toString());
  }

  encodePayload(payload) {
    const json = JSON.stringify(payload);
    const bytes = new TextEncoder().encode(json);
    let binary = '';

    bytes.forEach(byte => {
      binary += String.fromCharCode(byte);
    });

    return btoa(binary);
  }
}
