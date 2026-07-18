// SPDX-License-Identifier: MIT

import QtQml

QtObject {
    function isPreviewable(entryUrl: url): bool {
        const entryUrlString = entryUrl.toString().toLowerCase();
        for (const ext of [".gif", ".jpg", ".jpeg", ".png", ".svg", ".webp"]) {
            if (entryUrlString.endsWith(ext)) {
                return true;
            }
        }
        return false;
    }
}
