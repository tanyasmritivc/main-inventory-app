import type { Layout } from './types';

/** One in-flight save per Space. A conflict stops writes until explicit reload. */
export class LayoutWriter {
  private latest: Layout | null = null;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private running: Promise<void> | null = null;
  private stopped = false;
  private failure: unknown = null;
  constructor(private revision: number,
    private send: (layout: Layout, revision: number) => Promise<{ revision: number }>,
    private status: (state: 'saving' | 'saved' | 'error', error?: unknown) => void) {}
  queue(layout: Layout) {
    if (this.stopped || this.failure) return;
    this.latest = structuredClone(layout);
    if (this.timer) clearTimeout(this.timer);
    this.status('saving');
    this.timer = setTimeout(() => { void this.flush().catch(() => {}); }, 450);
  }
  async flush(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    if (this.failure) throw this.failure;
    if (this.running) { await this.running; if (this.latest) return this.flush(); return; }
    if (this.stopped || !this.latest) return;
    this.running = this.drain();
    try { await this.running; } finally { this.running = null; }
  }
  private async drain() {
    try {
      while (this.latest && !this.stopped) {
        const layout = this.latest;
        this.latest = null;
        const result = await this.send(layout, this.revision);
        this.revision = result.revision;
      }
      if (!this.stopped) this.status('saved');
    } catch (error) {
      this.failure = error;
      if (!this.stopped) this.status('error', error);
      throw error;
    }
  }
  dispose() { this.stopped = true; this.latest = null; if (this.timer) clearTimeout(this.timer); }
}
