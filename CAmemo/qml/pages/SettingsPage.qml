import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "../i18n.js" as I18n

Page {
    id: page
    allowedOrientations: Orientation.All

    property string currentLanguage: I18n.currentLang || "en"

    // Reaktiv hjelpefunksjon for dynamisk oversettelse
    function t(key) {
        var dummy = page.currentLanguage
        return I18n.tr(key)
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            page.currentLanguage = I18n.currentLang
        }
    }

    Python {
        id: python
        property bool ready: false

        Component.onCompleted: {
            var resolved = Qt.resolvedUrl("../").toString()
            var importPath = resolved.replace(/^file:\/\//, "")
            addImportPath(importPath)

            importModule("nb_backend", function() {
                python.ready = true
                call("nb_backend.get_setting", ["language", "en"], function(lang) {
                    if (lang) {
                        I18n.currentLang = lang
                        page.currentLanguage = lang
                        updateComboBoxSelection(lang)
                    }
                })
            })
        }

        function saveLanguageSetting(langCode) {
            call("nb_backend.save_setting", ["language", langCode], function(result) {
                if (result === "OK") {
                    I18n.currentLang = langCode
                    page.currentLanguage = langCode
                } else {
                    console.log("Feil ved lagring av spraak: " + result)
                }
            })
        }
    }

    function updateComboBoxSelection(langCode) {
        var languages = ["no", "sv", "da", "fi", "en", "de"]
        var index = languages.indexOf(langCode)
        if (index !== -1) {
            langComboBox.currentIndex = index
        }
    }

    // Funksjon for å åpne CreateNoteDialog
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

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        // Nedtrekksmeny med "Nytt notat" øverst
        PullDownMenu {
            MenuItem {
                text: page.t("create_note")
                onClicked: openCreateNoteDialog()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: page.t("settings")
            }

            // Språkvelger med beskjed om omstart
            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                ComboBox {
                    id: langComboBox
                    width: parent.width
                    label: page.t("language")

                    menu: ContextMenu {
                        MenuItem {
                            text: "Norsk"
                            onClicked: python.saveLanguageSetting("no")
                        }
                        MenuItem {
                            text: "Svenska"
                            onClicked: python.saveLanguageSetting("sv")
                        }
                        MenuItem {
                            text: "Dansk"
                            onClicked: python.saveLanguageSetting("da")
                        }
                        MenuItem {
                            text: "Suomi"
                            onClicked: python.saveLanguageSetting("fi")
                        }
                        MenuItem {
                            text: "English"
                            onClicked: python.saveLanguageSetting("en")
                        }
                        MenuItem {
                            text: "Deutsch"
                            onClicked: python.saveLanguageSetting("de")
                        }
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - (Theme.horizontalPageMargin * 2)
                    text: page.t("restart_required_desc")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    wrapMode: Text.WordWrap
                }
            }

            // Papirkurv-knapp
            ValueButton {
                width: parent.width
                label: page.t("trash")
                value: page.t("open_basket")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("BasketPage.qml"))
                }
            }
        }
    }
}
