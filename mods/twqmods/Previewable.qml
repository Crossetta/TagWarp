// SPDX-License-Identifier: MIT

import QtQml

/*!
    \qmltype Previewable
    \brief Defines whether a file can be viewed in the application.

    Decides by file extension. Used by \l Preview and \l MiniPreview, has some helper functions for them.
*/
QtObject {
    property list<string> images: [".gif", ".jpg", ".jpeg", ".png", ".svg", ".webp"]
    property list<string> videos: [".avi", ".flv", ".mkv", ".mov", ".m4v", ".mp4", ".mpeg", ".ts", ".vob", ".webm", ".wmv"]
    property list<string> audios: [".aac", ".aiff", ".alac", ".flac", ".m4a", ".mp3", ".oga", ".ogg", ".opus", ".wav", ".wma"]

    /*!
        \qmlmethod bool Previewable::isPreviewable(url entryUrl)
        \brief Returns true if \a entryUrl is suitable for \l Preview or \l MiniPreview.
    */
    function isPreviewable(entryUrl: url): bool {
        const entryUrlString = entryUrl.toString().toLowerCase();
        for (const ext of [].concat(images, videos, audios)) {
            if (entryUrlString.endsWith(ext)) {
                return true;
            }
        }
        return false;
    }

    /*!
        \qmlmethod bool Previewable::isSvg(url entryUrl)
        \brief Returns true if \a entryUrl has an .svg file name extension.
    */
    function isSvg(entryUrl: url): bool {
        return entryUrl.toString().toLowerCase().endsWith(".svg")
    }

    /*!
        \qmlmethod bool Previewable::isGif(url entryUrl)
        \brief Returns true if \a entryUrl has a .gif file name extension.
    */
    function isGif(entryUrl: url): bool {
        return entryUrl.toString().toLowerCase().endsWith(".gif")
    }

    /*!
        \qmlmethod bool Previewable::isVideo(url entryUrl)
        \brief Returns true if \a entryUrl has one of known video file name extensions.
    */
    function isVideo(entryUrl: url): bool {
        const entryUrlString = entryUrl.toString().toLowerCase();
        for (const ext of videos) {
            if (entryUrlString.endsWith(ext)) {
                return true;
            }
        }
        return false;
    }

    /*!
        \qmlmethod bool Previewable::isAudio(url entryUrl)
        \brief Returns true if \a entryUrl has one of known audio file name extensions.
    */
    function isAudio(entryUrl: url): bool {
        const entryUrlString = entryUrl.toString().toLowerCase();
        for (const ext of audios) {
            if (entryUrlString.endsWith(ext)) {
                return true;
            }
        }
        return false;
    }
}
