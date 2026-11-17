import type { Metadata } from 'next';
import { CadDocs } from '@/components/site/cad-docs';

export const metadata: Metadata = {
  title: 'CAD Intelligence documentation',
  description: 'FindEZ CAD documentation: Fusion downloads, installation, inventory connections, your first generated model, Fusion model insertion, saved BOMs, inventory comparison, Onshape CSV, matching, limits and troubleshooting.',
  alternates: { canonical: '/docs/cad' },
  openGraph: { title: 'CAD Intelligence documentation | FindEZ', description: 'Connect your design to your inventory. Setup, workflows and reference in one place.', url: 'https://findez.ai/docs/cad' },
};

export default async function CadDocumentationPage({ searchParams }: { searchParams: Promise<{ world?: string | string[] }> }) {
  const params = await searchParams;
  const world = typeof params.world === 'string' && params.world.length <= 200 ? params.world : undefined;
  return <CadDocs world={world} />;
}
