# 1.1.0-alpha

## Added

- Preview gifs and videos.
- Choose which frame of the video/gif to use as a thumbnail.
- "Hidden" and "Blurred" properties for tags.
- Built-in hidden and blurred tags.
- Tag deletion confirmation dialog.
- Switching between tag grouped by categories or by color.
- Hiding a tag from a category.
- Modding documentation.

## Build

- Windows: filter out unused DLLs.
- macOS: CMake version detection and initial packaging script.

## Fixed

- Per-entry multiple tags with parents overrides save.
- Multiple tag deletion from a library.
- Clearing tags doesn't clear description any more.
- Now clears tag selection when changing libraries.
- Tag color sorting in the library doesn't mess up alphabetical sorting now.
- Bulk tag color change.
- Cache storage options GUI now applies the correct choice.
- Creating tags over a loaded tag id cache doesn't erase tags any more.
- Moving with arrows in fullwindow preview now changes selection instead of adding to it.
- Recalc sidecar CRC after operations for rescan comparisons and consistency check.
- Pool regrow leak removed.
- Remove complex thread_local to fix mods hot reload.
- Thumbnail creation race.

# 1.0.0-alpha

## Added

- File tagging with some simple undo/redo and navigation history.
- Parent tags.
- Search by tags and names.
- Fullscreen preview.
- Multiple tag libraries.
- Multiple locations with multiple roots per location.
- Multiple windows and tabs, command palette.
- Several storage options for the tags: centralized, distributed, consolidated.
- Image thumbnails and multiple storage options for the thumbnails.
- QML and native modding systems.
