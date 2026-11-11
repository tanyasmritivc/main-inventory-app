"""Wire the commerce card into the newer deployed world dashboard.

The commerce branch predates world-navigation/world-tools. Apply this small,
guarded overlay to a copy of the live frontend; never replace that frontend with
the older branch. The two commerce-dashboard-card source files must be copied
from this branch into the candidate before building.
"""
from pathlib import Path
import sys


def patch(frontend: Path):
    tools = frontend / 'src/components/site/world-tools.tsx'
    navigation = frontend / 'src/lib/world-navigation.ts'
    original_tools, original_navigation = tools.read_text(), navigation.read_text()
    assert 'CommerceDashboardCard' not in original_tools, 'Dashboard overlay already applied'
    assert 'label: "Connections"' not in original_navigation, 'Connections navigation already exists'
    anchor = '    <div className={styles.grid}>'
    assert original_tools.count(anchor) == 1
    new_tools = original_tools.replace('import styles from "./world-tools.module.css";',
        'import styles from "./world-tools.module.css";\nimport { CommerceDashboardCard } from "./commerce-dashboard-card";', 1)
    assert new_tools != original_tools
    new_tools = new_tools.replace(anchor,
        '    <CommerceDashboardCard inventoryId={inventory.inventory_id} />\n' + anchor, 1)
    anchor = '      {\n        label: "Workspaces",'
    assert original_navigation.count(anchor) == 1 and original_navigation.count('  Wrench,') == 1
    new_navigation = original_navigation.replace('  Wrench,', '  Wrench,\n  Plug,', 1)
    new_navigation = new_navigation.replace(anchor, '''      {
        label: "Connections",
        route: worldHref(world, "tools") + "#findez-connect",
        icon: Plug,
        section: "Organization",
      },
''' + anchor, 1)
    tools.write_text(new_tools)
    navigation.write_text(new_navigation)


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
