import QtQuick 2.0
import Sailfish.Silica 1.0
import "../i18n.js" as I18n

Page {
    id: createNotePage
    allowedOrientations: Orientation.All

    property var python: null
    property var folderList: ["/"]
    property string selectedFolder: "/"
    property alias noteContent: contentField.text
    property string currentLanguage: I18n.currentLang || "en"

    // Funksjon for å hente mapper fra Python
    function loadFolders() {
        if (python) {
            python.call('nb_backend.get_folders', [], function(result) {
                if (result && Array.isArray(result)) {
                    var list = result.slice()
                    if (list.indexOf("/") === -1) {
                        list.unshift("/")
                    }
                    createNotePage.folderList = list
                }
            })
        }
    }

    // Felles funksjon for å lagre notatet
    function saveNote() {
        var targetFolder = "/"
        if (folderComboBox.currentItem) {
            targetFolder = folderComboBox.currentItem.text
        } else if (createNotePage.folderList.length > 0) {
            targetFolder = createNotePage.folderList[folderComboBox.currentIndex] || "/"
        }

        if (contentField.text.trim().length > 0) {
            if (python) {
                python.call("nb_backend.create_note", [contentField.text, null, targetFolder], function(success) {
                    if (success) {
                        pageStack.pop()
                    }
                })
            } else {
                pageStack.pop()
            }
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            createNotePage.currentLanguage = I18n.currentLang || "en"
            loadFolders()

            // Sørg for at den vedhjelpte siden kobles på når siden blir aktiv
            if (!createNotePage.attachedPage) {
                pageStack.pushAttached(saveSwipeComponent)
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: createNotePage.currentLanguage ? I18n.tr("cancel") : "Avbryt"
                onClicked: pageStack.pop()
            }
            MenuItem {
                text: createNotePage.currentLanguage ? I18n.tr("create") : "Lagre"
                enabled: contentField.text.trim().length > 0
                onClicked: saveNote()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: createNotePage.currentLanguage ? I18n.tr("create_note") : "Nytt notat"
                titleColor: Theme.highlightColor
            }

            ComboBox {
                id: folderComboBox
                width: parent.width
                label: createNotePage.currentLanguage ? I18n.tr("folder") : "Mappe"
                currentIndex: 0

                menu: ContextMenu {
                    id: folderMenu
                    Repeater {
                        model: createNotePage.folderList
                        MenuItem {
                            text: modelData
                        }
                    }
                }
            }

            TextArea {
                id: contentField
                width: parent.width
                placeholderText: createNotePage.currentLanguage ? I18n.tr("write_here") : "Skriv her..."
                label: createNotePage.currentLanguage ? I18n.tr("content") : "Innhold"
                height: Math.max(200, implicitHeight)
            }
        }
    }

    // --- SVEIPESIDE: SVEIP FOR Å LAGRE ---
    Component {
        id: saveSwipeComponent

        Page {
            allowedOrientations: Orientation.All

            onStatusChanged: {
                if (status === PageStatus.Active) {
                    // Lagrer med en gang man sveiper til denne siden
                    createNotePage.saveNote()
                }
            }

            SilicaFlickable {
                anchors.fill: parent

                Column {
                    anchors.centerIn: parent
                    width: parent.width - (2 * Theme.horizontalPageMargin)
                    spacing: Theme.paddingLarge

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "💾"
                        font.pixelSize: 64
                    }

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeLarge
                        text: createNotePage.currentLanguage ? I18n.tr("create") : "Lagrer..."
                    }
                }
            }
        }
    }
}
