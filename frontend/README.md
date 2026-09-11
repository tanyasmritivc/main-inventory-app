This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

### Public API documentation

The integration guide is served publicly at `/docs/api`, with downloads at
`/docs/api/guide.md` and `/docs/api/openapi.json`. Settings, API-key management,
and the landing-page footer link to it. It does not accept or execute credentials.

Maintain the guide and endpoint examples in `src/lib/api-docs.ts`. The web page
and Markdown download share that content. `src/lib/api-openapi.ts` uses the same
endpoint registry plus request schemas exported from the actual FastAPI router
in `src/lib/api-request-schemas.json`; it also documents custom model validators
and response shapes. Do not invent endpoints to satisfy a documentation example.

`npm test -- --runInBand` includes documentation navigation, clipboard/error,
download, endpoint, auth-scope, and request-field drift checks. After `npm run build
-- --webpack`, run this additional read-only verification from the repository root:

```bash
backend/venv/bin/python frontend/scripts/verify-api-docs.py
```

It compares complete generated request schemas against the backend and validates
the example payloads and Python/JavaScript/shell syntax without calling the API.
Validate the built OpenAPI download with an OpenAPI 3.1 validator after contract
changes. Real-browser desktop/mobile/print review remains a separate check.
Production is self-hosted; follow the repository's `CLAUDE.md` deployment guidance
and preserve unrelated server changes. The Vercel text below is scaffold boilerplate.

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
