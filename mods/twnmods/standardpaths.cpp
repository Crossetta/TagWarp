// SPDX-License-Identifier: MIT

/*!
    \brief Tag library storage and application's cache path override.

    Functions that application uses to determine where to store various data.
*/

#include <QByteArray>
#include <QStandardPaths>
#include <QStringList>
#include <climits>
#include <cstring>

#include "tweerrorcheckutilslibc.h"
#include "twestandardpaths.h"

#define TW_MAX_PATHS_COUNT 16

// NOLINTNEXTLINE(cppcoreguidelines-avoid-non-const-global-variables)
thread_local static char  pathsBuffer[PATH_MAX * TW_MAX_PATHS_COUNT];
thread_local static char *paths[TW_MAX_PATHS_COUNT + 1]; // NOLINT(cppcoreguidelines-avoid-non-const-global-variables)

#ifdef __cplusplus
extern "C" {
#endif

/*!
    \fn char *twStandardLocations(TWStandardLocation type, char **err)
    \brief Returns all the directories where files of \a type belong.

    Returned array is \c NULL terminated.

    Subsequent calls invalidate pointers returned from previous calls.

    May fail and set the \a err.
*/
TW_EXPORT char **twStandardLocations(TWStandardLocation type, char **err) {
    QStandardPaths::StandardLocation qtLocation; // NOLINT(cppcoreguidelines-init-variables)
    switch (type) {
    case TW_STANDARD_LOCATION_CACHE:
        qtLocation = QStandardPaths::CacheLocation;
        break;
    case TW_STANDARD_LOCATION_APP_DATA:
        qtLocation = QStandardPaths::AppDataLocation;
        break;
    default:
        EB_ERR_GF(false, "Invalid path type specified");
    }

    {
        QStringList qtPaths = QStandardPaths::standardLocations(qtLocation);
        EB_ERR_GF(qtPaths.size() <= TW_MAX_PATHS_COUNT, "Too many paths returned by QStandardPaths::standardLocations");

        for (size_t i = 0, offs = 0; i < qtPaths.size(); ++i) {
            QByteArray pathAsUtf8 = qtPaths[i].toUtf8();
            size_t     pathLen    = pathAsUtf8.size() + 1;
            EB_ERR_GF(pathLen <= PATH_MAX, "Standard path is too long");
            paths[i] = &pathsBuffer[offs];
            memcpy(paths[i], pathAsUtf8.constData(), pathLen);
            offs += pathLen;
        }

        paths[qtPaths.size()] = nullptr;
    }

fail:
    return paths;
}

#ifdef __cplusplus
}
#endif
