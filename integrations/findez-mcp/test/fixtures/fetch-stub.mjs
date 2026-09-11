// Used only by the packaged-process test. No request can leave this process.
globalThis.fetch = async (url, options) => new Response(JSON.stringify({
  url, method: options.method, body: options.body ? JSON.parse(options.body) : null,
  authenticated: options.headers.Authorization === 'Bearer ' + process.env.FINDEZ_API_KEY,
}), { headers: { 'content-type': 'application/json' } });
