// SPDX-License-Identifier: MIT

import QtQuick

import com.TagWarp.Manager 1.0
import twqmods 1.0
import twnmods 1.0

ShortcutsWithAltDetectionAndText {
    id: root

    actions: [
        {
            action: window.actionCommandSearch,
            sequences: ["Ctrl+Shift+P"]
        },
        {
            action: window.actionUndo,
            sequences: [StandardKey.Undo]
        },
        {
            action: window.actionRedo,
            sequences: ["Ctrl+Y", StandardKey.Redo]
        },
        {
            action: window.actionGoUpDir,
            sequences: ["Alt+Up"]
        },
        {
            action: window.actionGoToCurrentDir,
        },
        {
            action: window.actionGoToRoots,
        },
        {
            action: window.actionBack,
            sequences: [StandardKey.Back]
        },
        {
            action: window.actionForward,
            sequences: [StandardKey.Forward]
        },
        {
            action: window.actionIncThumbnailsZoom,
            sequences: [StandardKey.ZoomIn, Qt.platform.os === "windows" ? "Ctrl+=" : "Ctrl+'='"]
        },
        {
            action: window.actionDecThumbnailsZoom,
            sequences: [StandardKey.ZoomOut]
        },
        {
            action: window.actionAddTab,
            sequences: ["Ctrl+T"]
        },
        {
            action: window.actionCloseTab,
            sequences: [StandardKey.Close]
        },
        {
            action: window.actionPreviousTab,
            sequences: ["Ctrl+PgUp"]
        },
        {
            action: window.actionNextTab,
            sequences: ["Ctrl+PgDown"]
        },
        {
            action: window.actionNewWindow,
            sequences: [StandardKey.New]
        },
        {
            action: window.actionToggleFullscreen,
            sequences: [StandardKey.Fullscreen, "F11"]
        },
        {
            action: window.actionCreateFolder,
            sequences: ["Ctrl+Shift+N"]
        },
        {
            action: window.actionFind,
            sequences: [StandardKey.Find]
        },
        {
            action: window.actionApplyTags,
            sequences: ["Ctrl+Shift+A"]
        },
        {
            action: window.actionStripTags,
            sequences: ["Ctrl+Shift+S"]
        },
        {
            action: window.actionToggleShowIds,
            sequences: ["Ctrl+Shift+Alt+I"]
        },
        {
            action: window.actionToggleLegacyGridView,
            sequences: ["Ctrl+Shift+Alt+L"]
        },
        {
            action: window.actionToggleLegacyTagsView,
            sequences: ["Ctrl+Shift+Alt+T"]
        },
        {
            action: window.actionToggleShowUndoStackWindow,
            sequences: ["Ctrl+Shift+Alt+U"]
        },
        {
            action: window.actionShowSystemPaletteWindow,
            sequences: ["Ctrl+Shift+Alt+P"]
        },
        {
            action: window.actionReloadQml,
            sequences: ["Shift+F5"]
        },
        {
            action: window.actionReloadQmlAndMods,
            sequences: ["Ctrl+Shift+F5"]
        },
        {
            action: window.actionPopOut,
        },
        {
            action: window.actionViewFullwindow,
        },
        {
            action: window.actionAbout,
        },
        {
            action: window.actionBrowseSettingsFile,
        },
        {
            action: window.actionBrowseTagLibrariesStorageDirectory,
        },
        {
            action: window.actionSaveSystemInfo,
        },
        {
            action: window.actionSettings,
            sequences: ["Ctrl+Shift+O"]
        },
    ]
}
