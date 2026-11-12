// Browser APIs omitted by JSDOM. Individual interaction tests may override these.
if (typeof window !== "undefined") {
  if (!window.matchMedia) Object.defineProperty(window, "matchMedia", { writable: true, configurable: true, value: (query: string): MediaQueryList => ({
    matches: false, media: query, onchange: null,
    addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
  }) });
  if (!globalThis.ResizeObserver) globalThis.ResizeObserver = class implements ResizeObserver {
    observe() {} unobserve() {} disconnect() {}
  };
}
