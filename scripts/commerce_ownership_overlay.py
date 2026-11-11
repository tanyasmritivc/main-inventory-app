"""Apply owner-scope entry points to the newer live web tree without replacing it."""
from pathlib import Path
import shutil
import sys


def replace(path, old, new):
    text = path.read_text()
    if new in text:
        return
    assert text.count(old) == 1, f'Inspect changed live source before patching {path.name}'
    path.write_text(text.replace(old, new, 1))


def patch(frontend: Path):
    source = Path(__file__).resolve().parents[1] / 'frontend'
    for name in ['src/components/site/settings-connections.tsx', 'src/components/site/settings-connections.module.css', 'src/components/site/commerce-client.tsx',
                 'src/components/site/amazon-history-import.tsx', 'src/components/site/commerce-dashboard-card.tsx',
                 'src/lib/commerce.ts', 'src/app/(workspace)/inventory/connect/page.tsx']:
        shutil.copy2(source / name, frontend / name)
    replace(frontend / 'src/lib/inventory-selection.ts', 'export function isInventoryPage(path: string) {',
            'export function isInventoryPage(path: string) {\n  if (/^\\/inventory\\/connect\\/?$/.test(path.split("?")[0])) return false;')
    replace(frontend / 'src/components/site/app-sidebar.tsx', 'route: "/inventory/connect"', 'route: "/settings/connections"')
    replace(frontend / 'src/lib/world-navigation.ts', 'route: "/settings/connections",',
            'route: world === "personal" ? "/settings/connections" : `/settings/connections?organization=${encodeURIComponent(world)}`,')
    replace(frontend / 'src/components/site/settings-client.tsx', 'Manage your purchase and store connections.',
            'Manage private Personal purchases or organization connections. Choose an inventory only when adding items you still own.')
    # The existing Add context link is for AI assistants, not merchant connections.
    replace(frontend / 'src/components/site/chat-plus-menu.tsx', '                Connections\n', '                AI assistant integrations\n')
    tools = frontend / 'src/components/site/world-tools.tsx'
    replace(tools, '({accountId, inventories}: {accountId: string; inventories: Inventory[]})',
            '({accountId, inventories, organizationId}: {accountId: string; inventories: Inventory[]; organizationId?: string})')
    replace(tools, 'if (!inventory) return <p className={styles.empty}>Create an inventory to use these tools.</p>;',
            'if (!inventory) return <div className={styles.page}><CommerceDashboardCard organizationId={organizationId} /><p className={styles.empty}>Create an inventory to use the inventory tools below.</p></div>;')
    replace(tools, '<CommerceDashboardCard inventoryId={inventory.inventory_id} />', '<CommerceDashboardCard organizationId={organizationId} />')
    replace(frontend / 'src/components/site/world-workspace.tsx', '<WorldTools accountId={accountId} inventories={inventories} />',
            '<WorldTools accountId={accountId} inventories={inventories} organizationId={worldId === "personal" ? undefined : worldId} />')


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
