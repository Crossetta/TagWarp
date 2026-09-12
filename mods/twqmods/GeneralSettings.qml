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
*/
ColumnLayout {
    id: root

    /*!
        \qmlsignal GeneralSettings::close()
        \brief Emitted to close the whole settings window.
    */
    signal close

    spacing: 0

    Row {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop

        Label { text: qsTr("Show hidden files:") }
        CheckBox {
            id: showHiddenEntriesCheckBox
            checked: GlobalState.showHiddenEntries
        }
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
            enabled: GlobalState.showHiddenEntries != showHiddenEntriesCheckBox.checked
            onClicked: {
                GlobalState.showHiddenEntries = showHiddenEntriesCheckBox.checked;
            }
        }
        Button {
            text: qsTr("Revert")
            enabled: applyButton.enabled
            onClicked: {
                showHiddenEntriesCheckBox.checked = GlobalState.showHiddenEntries;
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
        if (event.key == Qt.Key_Escape) {
            if (!applyButton.enabled) {
                root.close();
            }
        }
    }
}
