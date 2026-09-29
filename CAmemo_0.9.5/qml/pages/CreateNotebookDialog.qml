import QtQuick 2.0
import Sailfish.Silica 1.0
import "../i18n.js" as I18n

Dialog {
    id: dialog
    allowedOrientations: Orientation.All

    property alias notebookName: nameInput.text
    property var python
    property string currentLanguage: I18n.currentLang || "en"

    canAccept: nameInput.text.trim().length > 0

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: dialog.currentLanguage ? I18n.tr("cancel") : ""
                onClicked: dialog.reject()
            }
            MenuItem {
                text: dialog.currentLanguage ? I18n.tr("create") : ""
                enabled: dialog.canAccept
                onClicked: dialog.accept()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: dialog.currentLanguage ? I18n.tr("create_notebook") : ""
            }

            TextField {
                id: nameInput
                width: parent.width - (Theme.horizontalPageMargin * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                placeholderText: dialog.currentLanguage ? I18n.tr("enter_folder_name") : ""
                label: dialog.currentLanguage ? I18n.tr("folder_name") : ""
                focus: true

                EnterKey.enabled: dialog.canAccept
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: dialog.accept()
            }
        }
    }
}
