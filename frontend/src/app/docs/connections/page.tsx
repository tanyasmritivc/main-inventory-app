import type { Metadata } from 'next';
import { ConnectionsDocs } from '@/components/site/connections-docs';

export const metadata: Metadata = {
  title: 'Connections documentation',
  description: 'Import Amazon order history, manage personal and organization purchase records, and check before buying. FindEZ Connections setup, limits and troubleshooting.',
  alternates: { canonical: '/docs/connections' },
};

export default async function ConnectionsDocumentationPage({ searchParams }: { searchParams: Promise<{ organization?: string | string[] }> }) {
  const params = await searchParams;
  const organization = typeof params.organization === 'string' && params.organization.length <= 200 ? params.organization : undefined;
  return <ConnectionsDocs organization={organization} />;
}
