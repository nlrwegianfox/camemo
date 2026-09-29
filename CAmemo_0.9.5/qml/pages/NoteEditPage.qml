import QtQuick 2.0
import Sailfish.Silica 1.0
import "../i18n.js" as I18n

Page {
    id: editNotePage
    allowedOrientations: Orientation.All

    property var python: null
    property string noteId: ""
    property alias noteContent: contentField.text
    property string currentLanguage: I18n.currentLang || "en"

    // Funksjon for å laste inn eksisterende innhold i notatet
    function loadNoteContent() {
        if (python && noteId !== "") {
            python.call('nb_backend.get_note_content', [noteId], function(content) {
                if (content !== null && content !== undefined) {
                    contentField.text = content
                }
            })
        }
    }

    // Felles lagringsfunksjon for både nedtrekksmeny og sveip
    function saveNote() {
        if (contentField.text.trim().length > 0) {
            if (python && noteId !== "") {
                python.call("nb_backend.save_note_content", [noteId, contentField.text])
            }
            // Tvinger stakken tilbake til visningssiden
            pageStack.pop(pageStack.previousPage())
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            editNotePage.currentLanguage = I18n.currentLang || "en"
            loadNoteContent()

            // Legger til den vedhjelpte siden slik at sveip til venstre fungerer igjen
            if (!editNotePage.attachedPage) {
                pageStack.pushAttached(saveSwipeComponent)
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        // Dra-ned-meny for Avbryt og Lagre
        PullDownMenu {
            MenuItem {
                text: editNotePage.currentLanguage ? I18n.tr("cancel") : "Avbryt"
                onClicked: pageStack.pop()
            }
            MenuItem {
                text: editNotePage.currentLanguage ? I18n.tr("save") : "Lagre"
                enabled: contentField.text.trim().length > 0
                onClicked: saveNote()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: editNotePage.currentLanguage ? I18n.tr("edit_note") : "Rediger notat"
                titleColor: Theme.highlightColor
            }

            TextArea {
                id: contentField
                width: parent.width
                placeholderText: editNotePage.currentLanguage ? I18n.tr("write_here") : "Skriv her..."
                label: editNotePage.currentLanguage ? I18n.tr("content") : "Innhold"
                height: Math.max(300, implicitHeight)
            }
        }
    }

    // --- SVEIPESIDE: SVEIP TIL VENSTRE FOR Å LAGRE ---
    Component {
        id: saveSwipeComponent

        Page {
            allowedOrientations: Orientation.All

            onStatusChanged: {
                if (status === PageStatus.Active) {
                    // Utløser akkurat den samme lagringsfunksjonen ved sveip
                    editNotePage.saveNote()
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
                        text: editNotePage.currentLanguage ? I18n.tr("save") : "Lagrer..."
                    }
                }
            }
        }
    }
}
