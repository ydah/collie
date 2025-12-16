// Ruby.wasm runner for the playground

class RubyRunner {
  constructor() {
    this.vm = null;
    this.isReady = false;
  }

  async initialize() {
    try {
      await this.waitForRubyWasm();

      if (typeof window.rubyWasm === 'object' && window.rubyWasm.eval) {
        this.vm = window.rubyWasm;
      } else if (window.rubyWasm && window.rubyWasm.DefaultRubyVM) {
        const { DefaultRubyVM } = window.rubyWasm;
        const response = await fetch(
          'https://cdn.jsdelivr.net/npm/@ruby/3.3-wasm-wasi@2.6.2/dist/ruby+stdlib.wasm'
        );
        const module = await WebAssembly.compileStreaming(response);
        const { vm } = await DefaultRubyVM(module);
        this.vm = vm;
      } else {
        throw new Error('Unexpected Ruby.wasm API structure');
      }

      await this.loadCollieBundle();

      this.isReady = true;
      return true;
    } catch (error) {
      console.error('Failed to initialize Ruby.wasm:', error);
      throw error;
    }
  }

  async waitForRubyWasm() {
    const maxAttempts = 50;
    let attempts = 0;
    const possibleNames = ['rubyVM', 'rubyWasm', 'RubyWasm', 'ruby', 'Ruby'];

    while (attempts < maxAttempts) {
      for (const name of possibleNames) {
        if (window[name]) {
          window.rubyWasm = window[name];
          return;
        }
      }

      await new Promise(resolve => setTimeout(resolve, 100));
      attempts++;
    }

    throw new Error('Ruby.wasm failed to load. Please refresh the page.');
  }

  async loadCollieBundle() {
    try {
      const response = await fetch(`collie-bundle.rb?v=${Date.now()}`);
      const code = await response.text();
      await this.eval(code);
    } catch (error) {
      console.error('Failed to load Collie bundle:', error);
      throw error;
    }
  }

  async eval(code) {
    if (!this.isReady && !code.includes('module Collie')) {
      throw new Error('Ruby VM is not ready');
    }

    return this.vm.eval(code);
  }
}
