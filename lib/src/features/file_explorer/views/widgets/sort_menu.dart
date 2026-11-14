import 'package:material_ui/material_ui.dart';

import '../../controllers/file_explorer_controller.dart';
import 'context_menu.dart';

/// Icon + label shown for every sort key.
const Map<ExplorerSortField, (IconData, String)> _sortOptions = {
  ExplorerSortField.name: (Icons.sort_by_alpha, 'Name'),
  ExplorerSortField.size: (Icons.straighten, 'Size'),
  ExplorerSortField.modified: (Icons.schedule, 'Modified'),
  ExplorerSortField.type: (Icons.category_outlined, 'Type'),
};

/// Builds the flat "view options" menu shared by the toolbar sort button and
/// the empty-area context menu: the sort key, its direction and dot-file
/// visibility.
List<ContextMenuEntry> buildSortMenuEntries(FileExplorerController controller) {
  return [
    for (final MapEntry<ExplorerSortField, (IconData, String)> option
        in _sortOptions.entries)
      ContextMenuActionEntry(
        ContextMenuAction(
          icon: option.value.$1,
          label: 'Sort by ${option.value.$2}',
          checked: controller.sortField.value == option.key,
          onSelected: () => controller.setSortField(option.key),
        ),
      ),
    ContextMenuSeparator(),
    ContextMenuActionEntry(
      ContextMenuAction(
        icon: Icons.arrow_upward,
        label: 'Ascending',
        checked: controller.sortAscending.value,
        onSelected: () => controller.setSortAscending(true),
      ),
    ),
    ContextMenuActionEntry(
      ContextMenuAction(
        icon: Icons.arrow_downward,
        label: 'Descending',
        checked: !controller.sortAscending.value,
        onSelected: () => controller.setSortAscending(false),
      ),
    ),
    ContextMenuSeparator(),
    ContextMenuActionEntry(
      ContextMenuAction(
        icon: controller.showHidden.value
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        label: 'Show hidden files',
        shortcut: 'Ctrl+H',
        checked: controller.showHidden.value,
        onSelected: controller.toggleHiddenFiles,
      ),
    ),
  ];
}
