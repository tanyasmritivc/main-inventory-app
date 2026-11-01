export const SETTINGS_SECTIONS = {
  organizations: "Organizations",
  profile: "Profile",
  appearance: "Appearance",
  memory: "AI memory",
  plans: "Plans & usage",
  developer: "Developer",
  help: "Help and information",
  account: "Account",
} as const;
export type SettingsSection = keyof typeof SETTINGS_SECTIONS;
export function isSettingsSection(value: string): value is SettingsSection {
  return Object.hasOwn(SETTINGS_SECTIONS, value);
}
