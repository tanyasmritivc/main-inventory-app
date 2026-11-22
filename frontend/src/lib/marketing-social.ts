export const shareTitle = "FindEZ AI | Engineering starts with knowing what you have";
export const shareDescription = "AI-powered physical inventory intelligence. Snap a shelf, ask what you have and where it is, and compare a CAD design with your inventory.";

const image = "/brand/findez-petals-512.png";
export function socialText(title: string, description: string, url: string, inheritedGraph = true) {
  return {
    openGraph: {
      title, description, url,
      ...(inheritedGraph ? {siteName: "FindEZ", type: "website" as const, images: [{url: image, width: 512, height: 512, alt: "FindEZ"}]} : {}),
    },
    twitter: {card: "summary" as const, title, description, images: [image]},
  };
}
