export function calendlyEvent(value?: string): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.origin !== 'https://calendly.com' || url.username || url.password ||
        !/^\/[\w-]+\/[\w-]+\/?$/.test(url.pathname) ||
        /^\/(?:app|api|integrations|help|features|blog|login|signup)\//i.test(url.pathname)) return null;
    return url.origin + url.pathname.replace(/\/$/, '');
  } catch {
    return null;
  }
}
