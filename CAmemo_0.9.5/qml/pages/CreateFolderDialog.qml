import QtQuick 2.0
import Sailfish.Silica 1.0
import "../i18n.js" as I18n

Dialog {
    id: dialog
    property alias inputValue: textInput.text

    canAccept: textInput.text.trim().length > 0

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: I18n.tr("cancel")
                onClicked: dialog.reject()
            }
            MenuItem {
                text: I18n.tr("create")
                enabled: dialog.canAccept
                onClicked: dialog.accept()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: I18n.tr("new_folder")
            }

            TextField {
                id: textInput
                width: parent.width - (2 * Theme.horizontalPageMargin)
                anchors.horizontalCenter: parent.horizontalCenter
                label: I18n.tr("folder_name")
                placeholderText: I18n.tr("enter_folder_name")
                focus: true
            }
        }
    }
}
