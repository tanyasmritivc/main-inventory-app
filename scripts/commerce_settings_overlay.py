"""Add regular Connections settings navigation to the newer live UI, preserving it."""
from pathlib import Path
import sys

def patch(frontend: Path):
    settings = frontend/'src/components/site/settings-client.tsx'
    sections = frontend/'src/lib/settings-sections.ts'
    shell = frontend/'src/components/site/app-shell.tsx'
    a,b,c = settings.read_text(),sections.read_text(),shell.read_text()
    assert 'SettingsConnections' not in a and 'connections: "Connections"' not in b
    assert a.count('    <div className="settings-content">') == 1
    assert a.count('      {section === "appearance"') == 1
    a=a.replace('"use client";', '"use client";\nimport { SettingsConnections } from "./settings-connections";',1)
    a=a.replace('    <div className="settings-content">','    <div className="settings-content">\n      {section === "connections" && <SettingsConnections />}',1)
    card='      {section === "profile" && <section className="settings-panel"><header><h2>Connections</h2></header><div className="settings-row"><div><strong>Amazon &amp; Shopify</strong><small>Manage your purchase and store connections.</small></div><Link href="/settings/connections" className="workspace-button">Manage connections</Link></div></section>}\n\n'
    a=a.replace('      {section === "appearance"',card+'      {section === "appearance"',1)
    assert b.count('  profile: "Profile",') == 1
    b=b.replace('  profile: "Profile",','  profile: "Profile",\n  connections: "Connections",',1)
    assert c.count('  CreditCard,') == 1
    c=c.replace('  CreditCard,','  CreditCard,\n  Plug,',1)
    anchor='    {\n      label: "Appearance",'
    assert c.count(anchor) == 1
    c=c.replace(anchor,'''    {
      label: "Connections",
      route: "/settings/connections",
      icon: Plug,
      section: "Account settings",
    },
'''+anchor,1)
    settings.write_text(a);sections.write_text(b);shell.write_text(c)

if __name__ == '__main__':patch(Path(sys.argv[1]))
