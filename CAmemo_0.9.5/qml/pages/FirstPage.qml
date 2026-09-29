import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "../i18n.js" as I18n

Page {
    id: page
    allowedOrientations: Orientation.All

    // Tilstandsflagg for å hindre at FavoritesPage skyves på stabelen mer én gang
    property bool attachedPushed: false
    // Lokal variabel for å trigge automatisk oppdatering av tekst i grensesnittet
    property string currentLanguage: I18n.currentLang || "en"

    onStatusChanged: {
        if (status === PageStatus.Active) {
            // Oppdaterer språk-bindingen hver gang siden blir aktiv
            page.currentLanguage = I18n.currentLang || "en"

            if (!attachedPushed) {
                // Kobler til FavoritesPage på høyre side slik at brukeren kan sveipe til den
                pageStack.pushAttached(Qt.resolvedUrl("FavoritesPage.qml"))
                attachedPushed = true
            }
        }
    }

    // Python-integrasjon for å laste inn backend og lese lagrede innstillinger
    Python {
        id: python
        property bool ready: false

        Component.onCompleted: {
            var resolved = Qt.resolvedUrl("../").toString()
            var importPath = resolved.replace(/^file:\/\//, "")
            addImportPath(importPath)

            importModule("nb_backend", function() {
                python.ready = true
                // Hent lagret språk fra innstillinger/config.json
                call("nb_backend.get_setting", ["language", "en"], function(lang) {
                    if (lang) {
                        I18n.currentLang = lang
                        page.currentLanguage = lang
                    }
                })
            })
        }
    }

    // Funksjon for å åpne CreateNoteDialog (gjenbrukes både fra menyen og bildet)
    function openCreateNoteDialog() {
        var dialog = pageStack.push(Qt.resolvedUrl("CreateNoteDialog.qml"), {
            "python": python
        })

        dialog.accepted.connect(function() {
            var content = dialog.noteContent ? dialog.noteContent.trim() : ""
            var folder = dialog.selectedFolder

            if (content.length > 0 && python.ready) {
                python.call("nb_backend.create_note", [content, folder], function(success) {
                    if (success) {
                        // Notatet ble opprettet
                    }
                })
            }
        })
    }

    // Rullbar beholder tilpasset Sailfish OS
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: parent.height

        // Dra-ned-meny med Innstillinger øverst og Nytt notat nederst
        PullDownMenu {
            MenuItem {
                text: page.currentLanguage ? I18n.tr("settings") : "Innstillinger"
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: page.currentLanguage ? I18n.tr("create_note") : "Nytt notat"
                onClicked: openCreateNoteDialog()
            }
        }

        // Sentrert kolonne for innholdet
        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingLarge * 2
            width: parent.width - (2 * Theme.horizontalPageMargin)

            // 1. Klikkbart område med fiskeboll-bilde og tekst (fungerer som hyperkobling)
            Item {
                width: parent.width
                height: contentColumn.height

                MouseArea {
                    anchors.fill: parent
                    onClicked: openCreateNoteDialog()
                }

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: Theme.paddingMedium

                    // Fiskeboll-bildet
                    Image {
                        id: image
                        source: "createnote.png"
                        width: parent.width * 0.8
                        height: width
                        fillMode: Image.PreserveAspectFit
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Hovedteksten (ett hakk større og følger mobilens fargetema)
                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Label {
                            text: "Before you forget it,"
                            font.pixelSize: Theme.fontSizeExtraLarge
                            color: Theme.primaryColor
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            wrapMode: Text.Wrap
                        }

                        Label {
                            text: "add it to a note"
                            font.pixelSize: Theme.fontSizeExtraLarge
                            color: Theme.highlightColor
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // 2. Sveip-instruksjon plassert godt under fiskebollen
            Column {
                width: parent.width
                spacing: Theme.paddingMedium

                Icon {
                    source: "image://theme/icon-m-right"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Label {
                    text: page.currentLanguage ? I18n.tr("swipe_left") : "Sveip til venstre"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }
}
