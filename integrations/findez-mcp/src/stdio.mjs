import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { createFindEZServer } from './server.mjs';

try {
  const server = createFindEZServer({ apiKey: process.env.FINDEZ_API_KEY });
  await server.connect(new StdioServerTransport());
} catch {
  // stdout is reserved for MCP; never log credentials or upstream errors.
  process.stderr.write('FindEZ could not start. Check the API key in your connector settings.\n');
  process.exitCode = 1;
}
