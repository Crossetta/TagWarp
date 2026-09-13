// SPDX-License-Identifier: MIT

/*!
    \brief Portable mode for the config, tag library storage and application's cache path.

    Overrides paths so that the config is stored alongside the executable.
*/

#include <QStandardPaths>
#include <limits.h>
#include <string.h>

#include "tweerrorcheckutilslibc.h"
#include "twestandardpaths.h"

#include "modportablemode.h"

#define TW_MAX_PATHS_COUNT 16

thread_local static char  pathsBuffer[PATH_MAX * TW_MAX_PATHS_COUNT];
thread_local static char *paths[TW_MAX_PATHS_COUNT + 1];

#ifdef __cplusplus
extern "C" {
#endif

static QString portablePath() {
    return QDir().absoluteFilePath("modportablemode");
}

/*!
    \fn char *twStandardLocations(TWStandardLocation type, char **err)
    \brief Returns all the directories where files of \a type belong (portable mode).

    Portable mode means that the directories are alongside the executable.

    Returned array is \c NULL terminated.

    Subsequent calls invalidate pointers returned from previous calls.

    May fail and set the \a err.
*/
TW_EXPORT char **twStandardLocations(TWStandardLocation type, char **err) {
    QString path;
    switch (type) {
    case TW_STANDARD_LOCATION_CACHE:
        path = QDir(portablePath()).absoluteFilePath("cache");
        break;
    case TW_STANDARD_LOCATION_CONFIG:
        path = QDir(portablePath()).absoluteFilePath("config");
        break;
    case TW_STANDARD_LOCATION_APP_DATA:
        path = QDir(portablePath()).absoluteFilePath("appdata");
        break;
    default:
        EB_ERR_GF(false, "Invalid path type specified");
    }

    {
        QByteArray pathAsUtf8 = path.toUtf8();
        size_t     pathLen    = pathAsUtf8.size() + 1;
        EB_ERR_GF(pathLen <= PATH_MAX, "Standard path is too long");
        paths[0] = pathsBuffer;
        memcpy(paths[0], pathAsUtf8.constData(), pathLen);
        paths[1] = nullptr;
    }

fail:
    return paths;
}

#ifdef __cplusplus
}
#endif

ModPortableMode::ModPortableMode(QObject *parent) : QObject(parent) {}

QUrl ModPortableMode::getConfigPath() const {
    return QUrl::fromLocalFile(QDir(QDir(portablePath()).absoluteFilePath("config")).absoluteFilePath("TagWarp.conf"));
}
