# Search and browser identity — October 24, 2026

User requested the current echo logo in browser tabs/search and the exact title “FindEZ | AI for the physical world”. They also asked about Google sitelinks and a knowledge panel.

Audit: live favicon.ico matched the repository, and the SVG matched round/findez-favicon.svg from the latest supplied findez-logo-echo.zip exactly. The screenshots show older cached artwork. New stable /brand/findez-echo.svg, findez-echo-96.png, findez-echo.ico and findez-echo-touch.png paths carry identical canonical artwork. Existing icon URLs remain supported. Avoid further URL churn; Google recommends stable favicon URLs.

Root and homepage titles/social metadata use the requested identity. Interior page titles retain their page-specific prefix and use FindEZ as the suffix. WebSite and SoftwareApplication use FindEZ, with FindEZ AI retained as an alternate name; Organization uses the product name and retains AI Robots Inc. as legalName. No invented ratings, company dates, profiles or certifications. Pricing gains a unique title/description/canonical and a sitemap entry. Public auth/indexing policy is unchanged.

Google controls favicon/title recrawl, sitelinks and knowledge panels. This release does not claim to create a Google panel or submit an indexing request. Search Console access was not used. Owner next steps: submit https://findez.ai/sitemap.xml and request homepage indexing in URL Inspection. Maintain useful public pages and clear internal links, and consistent genuine brand information across official profiles. Google may take days or weeks to recrawl, and feature display is not guaranteed.

Primary references:
- https://developers.google.com/search/docs/appearance/favicon-in-search
- https://developers.google.com/search/docs/appearance/site-names
- https://developers.google.com/search/docs/appearance/sitelinks
- https://developers.google.com/search/docs/appearance/structured-data/organization
- https://support.google.com/knowledgepanel/answer/9163198
- https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl

Release: pending self-hosted production verification. No mobile, API, database, auth or navigation changes.
