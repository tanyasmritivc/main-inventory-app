/** @jest-environment jsdom */
import { render } from '@testing-library/react';
import { LandingV3 } from '@/components/landing-v3/LandingV3';
import { createLandingMotion } from '@/components/landing-v3/motion';
import { sectionProgress, createProgressSampler, type MotionState } from '@/components/landing-v3/useScrollProgress';
jest.mock('next/dynamic', () => ({__esModule: true, default: () => () => null}));
jest.mock('next/navigation', () => ({useRouter: () => ({push: jest.fn()})}));
jest.mock('@/components/landing-v3/useScrollProgress', () => ({
  ...jest.requireActual('@/components/landing-v3/useScrollProgress'),
  useScrollProgress: () => ({motion: {current: {}}, registerTools: jest.fn()}),
}));
const state = (): MotionState => ({mx: 0, my: 0, tx: 0, ty: 0, heroVis: 1, endVis: 0, reduce: true, toolsFrame: null});
const rect = (top: number, height: number) => ({top, height, bottom: top + height, left: 0, right: 390, width: 390, x: 0, y: top, toJSON() {return {};}});

test('entering progress stays negative, then advances through the pin and clamps', () => {
  expect(sectionProgress(844, 1688, 844, true)).toBe(-1);
  expect(sectionProgress(422, 1688, 844, true)).toBe(-.5);
  expect(sectionProgress(422, 1688, 844, false)).toBe(0);
  expect(sectionProgress(-422, 1688, 844, true)).toBe(.5);
  expect(sectionProgress(-2000, 1688, 844, true)).toBe(1);
});
test('the shared sampler smooths at the prototype rate and bypasses smoothing for reduced motion', () => {
  Object.defineProperty(window, 'innerHeight', {configurable: true, value: 844});
  const element = document.createElement('section');
  element.getBoundingClientRect = () => rect(-422, 1688);
  const sample = createProgressSampler();
  expect(sample('a', element, false)).toBe(.075);
  expect(sample('a', element, true)).toBe(.5);
  element.getBoundingClientRect = () => rect(900, 1688);
  expect(sample('a', element, true)).toBeNull();
});
for (const [width, height] of [[1440,900],[390,844]]) {
  test(`all story stages, sync receipt and cleanup at ${width}×${height}`, () => {
    Object.defineProperty(window, 'innerWidth', {configurable: true, value: width});
    Object.defineProperty(window, 'innerHeight', {configurable: true, value: height});
    const {container} = render(<LandingV3 />);
    const root = container.firstElementChild as HTMLElement;
    const remove = jest.spyOn(window, 'removeEventListener');
    let progress = 0;
    const fz = state();
    const motion = createLandingMotion(root, fz, () => progress);
    const style = (id: string) => root.querySelector<HTMLElement>(`#${id}`)!.style;
    expect(style('m').width).toBe(`${Math.min(720,width-32)}px`);
    expect(style('lComp').visibility).toBe('visible');
    expect(fz.heroVis).toBe(1);
    progress = .18; motion.frame(100);
    expect(style('lPhoto').visibility).toBe('visible');
    expect(root.querySelector('#cntA')!.textContent).toBe('6');
    expect(root.querySelector('#cntB')!.textContent).toBe('1');
    expect(fz.heroVis).toBe(0);
    progress = .35; motion.frame(200);
    expect(style('lCard').visibility).toBe('visible');
    expect(root.querySelector('#stA')!.getAttribute('data-dark')).toBe('1');
    progress = .6; motion.frame(300);
    expect(style('lCab').visibility).toBe('visible');
    expect(root.querySelector('#lcnt')!.textContent).toBe('19 items');
    expect(style('newRow').display).toBe('flex');
    progress = .85; motion.frame(400);
    expect(style('lChat').visibility).toBe('visible');
    expect(root.querySelector('#qt')!.textContent).toBe('Where are my batteries?');
    progress = 0; motion.frame(500);
    expect(root.querySelector('#lcnt')!.textContent).toBe('18 items');
    expect(style('newRow').display).toBe('none');
    motion.dispose();
    expect(remove.mock.calls.map(call => call[0])).toEqual(expect.arrayContaining(['resize','pointermove']));
    expect(root.dataset.ready).toBeUndefined();
    remove.mockRestore();
  });
}
