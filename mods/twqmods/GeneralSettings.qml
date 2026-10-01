// SPDX-License-Identifier: MIT

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import com.TagWarp.Manager 1.0
import twqmods 1.0
import twnmods 1.0

/*!
    \qmltype GeneralSettings
    \brief General settings tab.

    Used in the settings window.
*/
ColumnLayout {
    id: root

    /*!
        \qmlsignal GeneralSettings::close()
        \brief Emitted to close the whole settings window.
    */
    signal close

    spacing: 0

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop

        columns: 2

        Label { text: qsTr("Show hidden files:") }
        CheckBox {
            id: showHiddenEntriesCheckBox
            checked: GlobalState.showHiddenEntries
        }

        Label { text: qsTr("Default audio volume:") }
        Slider {
            id: defaultAudioVolumeSlider
            value: GlobalState.defaultAudioVolume
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignBottom

        spacing: 0

        Item {
            Layout.fillWidth: true
        }
        Button {
            id: applyButton
            text: qsTr("Apply")
            enabled: GlobalState.showHiddenEntries !== showHiddenEntriesCheckBox.checked || GlobalState.defaultAudioVolume !== defaultAudioVolumeSlider.value
            onClicked: {
                GlobalState.showHiddenEntries = showHiddenEntriesCheckBox.checked;
                GlobalState.defaultAudioVolume = defaultAudioVolumeSlider.value;
            }
        }
        Button {
            text: qsTr("Revert")
            enabled: applyButton.enabled
            onClicked: {
                showHiddenEntriesCheckBox.checked = GlobalState.showHiddenEntries;
                defaultAudioVolumeSlider.value = GlobalState.defaultAudioVolume;
            }
        }
        Button {
            text: qsTr("Close")
            onClicked: root.close()
        }
        Button {
            text: qsTr("Accept")
            onClicked: {
                applyButton.click();
                root.close();
            }
        }
    }

    Keys.onPressed: (event)=> {
        if (event.key === Qt.Key_Escape) {
            if (!applyButton.enabled) {
                root.close();
            }
        }
    }
}
