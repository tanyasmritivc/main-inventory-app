/** @jest-environment jsdom */
import { createToolsScene } from '@/components/landing-v3/toolsScene';
import type { MotionState } from '@/components/landing-v3/useScrollProgress';

jest.mock('three', () => ({ WebGLRenderer: jest.fn(() => { throw new Error('GPU unavailable'); }) }));
jest.mock('three/addons/geometries/RoundedBoxGeometry.js', () => ({}));
jest.mock('three/addons/environments/RoomEnvironment.js', () => ({}));
jest.mock('three/addons/utils/BufferGeometryUtils.js', () => ({}));

describe('landing without WebGL', () => {
  afterEach(() => jest.restoreAllMocks());

  it.each(['missing', 'throws', 'renderer failure'])('keeps the page usable when context is %s', (failure) => {
    const canvas = document.createElement('canvas');
    const tooltip = document.createElement('div');
    const context = jest.spyOn(canvas, 'getContext');
    if (failure === 'throws') context.mockImplementation(() => { throw new Error('Blocked'); });
    else context.mockReturnValue(failure === 'missing' ? null : {} as WebGL2RenderingContext);
    const state: MotionState = { mx: 0, my: 0, tx: 0, ty: 0, heroVis: 1, endVis: 0, reduce: false, toolsFrame: null };
    const scene = createToolsScene(canvas, tooltip, state);
    expect(canvas.hidden).toBe(true);
    expect(() => { scene.frame(100); scene.dispose(); }).not.toThrow();
  });
});
