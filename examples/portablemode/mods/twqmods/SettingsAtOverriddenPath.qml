// SPDX-License-Identifier: MIT

import QtCore
import QtQml

import com.TagWarp.Manager 1.0
import twqmods 1.0
import twnmods 1.0

/*!
    \qmltype SettingsAtOverriddenPath
    \brief An overridable definition of the Qt Settings QML type.

    Useful for the mods that need to override the path to the settings file.
*/
Settings {
    location: ModPortableMode.configPath
}
