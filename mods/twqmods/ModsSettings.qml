// SPDX-License-Identifier: MIT

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import com.TagWarp.Manager 1.0
import twqmods 1.0
import twnmods 1.0

ColumnLayout {
    id: root

    signal close

    spacing: 0

    GroupBox {
        Layout.fillWidth: true

        label: CheckBox {
            id: checkBox
            text: qsTr("Mods")
            checked: settings.enabled
        }

        GridLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            enabled: checkBox.checked

            columns: 2

            Label { text: qsTr("Directory:") }
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: directoryTextField
                    Layout.fillWidth: true
                    text: settings.dir
                }
                Button {
                    text: qsTr("Browse...")
                    onClicked: directoryDialog.open()
                }
            }
            FolderDialog {
                id: directoryDialog
                acceptLabel: qsTr("Select")
                onAccepted: {
                    let dirPathAsUri = directoryDialog.selectedFolder.toString();
                    const fileUriPrefix = "file://";
                    if (dirPathAsUri.startsWith(fileUriPrefix)) {
                        dirPathAsUri = dirPathAsUri.slice(fileUriPrefix.length);
                    }
                    const dirPath = decodeURIComponent(dirPathAsUri).substr(Qt.platform.os === "windows" ? 1 : 0);

                    directoryTextField.text = FilesystemFuncs.canonicalPath(dirPath);
                }
            }

            Label { text: qsTr("Debug:") }
            CheckBox {
                id: debugCheckBox
                checked: settings.debug
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true

        spacing: 0

        Item {
            Layout.fillWidth: true
        }
        Button {
            id: applyButton
            text: qsTr("Apply")
            enabled: settings.enabled != checkBox.checked ||
                settings.dir != directoryTextField.text ||
                settings.debug != debugCheckBox.checked
            onClicked: {
                settings.enabled = checkBox.checked;
                settings.dir = directoryTextField.text;
                settings.debug = debugCheckBox.checked;
            }
        }
        Button {
            text: qsTr("Revert")
            enabled: applyButton.enabled
            onClicked: {
                checkBox.checked = settings.enabled;
                directoryTextField.text = settings.dir;
                debugCheckBox.checked = settings.debug;
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

    Settings {
        id: settings
        category: "mods"
        property bool enabled
        property string dir
        property bool debug
    }
}
