// Keep public search, social previews and app identity consistent with the product.
export const PUBLIC_SITE_URL = "https://findez.ai";
export const PUBLIC_SITE_TITLE = "FindEZ AI | AI memory for the physical world";
export const PUBLIC_SITE_DESCRIPTION =
  "Turn the physical world into memory. Scan photos and barcodes, save items in Spaces, and ask FindEZ AI what you have and where it is.";
export const PUBLIC_SITE_UPDATED_AT = "2026-10-23";

// Public product facts only. Never include account, inventory or conversation data.
export const PUBLIC_SITE_STRUCTURED_DATA = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Organization",
      "@id": `${PUBLIC_SITE_URL}/#organization`,
      name: "AI Robots Inc.",
      url: PUBLIC_SITE_URL,
      logo: `${PUBLIC_SITE_URL}/brand/findez-logo-512.png`,
    },
    {
      "@type": "WebSite",
      "@id": `${PUBLIC_SITE_URL}/#website`,
      name: "FindEZ AI",
      alternateName: "FindEZ",
      url: PUBLIC_SITE_URL,
      description: PUBLIC_SITE_DESCRIPTION,
      publisher: { "@id": `${PUBLIC_SITE_URL}/#organization` },
      inLanguage: "en",
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${PUBLIC_SITE_URL}/#application`,
      name: "FindEZ AI",
      alternateName: "FindEZ",
      url: PUBLIC_SITE_URL,
      description: PUBLIC_SITE_DESCRIPTION,
      applicationCategory: "ProductivityApplication",
      operatingSystem: "iOS, Web",
      publisher: { "@id": `${PUBLIC_SITE_URL}/#organization` },
      downloadUrl: "https://apps.apple.com/us/app/findez-ai/id6760401697",
      featureList: [
        "Photo and barcode capture",
        "Save items and their locations in Spaces",
        "Ask questions about saved items and their context",
        "Search the things you own or manage",
        "Share access with your team",
      ],
    },
  ],
};
