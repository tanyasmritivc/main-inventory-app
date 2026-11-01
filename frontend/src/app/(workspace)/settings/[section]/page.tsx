import { notFound } from "next/navigation";
import { requireUser } from "@/lib/auth-guard";
import { SettingsClient } from "@/components/site/settings-client";
import { SETTINGS_SECTIONS, isSettingsSection } from "@/lib/settings-sections";

type Props = { params: Promise<{ section: string }> };
export async function generateMetadata({ params }: Props) {
  const { section } = await params;
  return { title: isSettingsSection(section) ? SETTINGS_SECTIONS[section] : "Settings" };
}
export default async function SettingsSectionPage({ params }: Props) {
  const { section } = await params;
  if (!isSettingsSection(section)) notFound();
  const user = await requireUser(`/settings/${section}`);
  return <section className="product-page settings-page">
    <header className="product-page-header"><h1>{SETTINGS_SECTIONS[section]}</h1></header>
    <SettingsClient email={user.email || null} section={section} />
  </section>;
}
