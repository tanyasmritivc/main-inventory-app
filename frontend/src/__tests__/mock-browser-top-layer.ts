// JSDOM has no native modal/popover top layer. Its selector engine recursively
// evaluates :modal through :fullscreen; Floating UI probes these browser states.
export function mockBrowserTopLayer() {
  const matches = Element.prototype.matches;
  let spy: jest.SpyInstance;
  beforeAll(() => {
    spy = jest.spyOn(Element.prototype, "matches").mockImplementation(function (this: Element, selector: string) {
      if ([":modal", ":popover-open", ":fullscreen"].includes(selector)) return false;
      return matches.call(this, selector);
    });
  });
  afterAll(() => spy.mockRestore());
}
