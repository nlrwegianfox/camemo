import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "../i18n.js" as I18n

Page {
    id: page
    allowedOrientations: Orientation.All

    // Reactive language tracking synchronized with I18n module
    property string currentLanguage: I18n.currentLang || "en"

    property string activeNotebookName: ""
    property string selectedNotebook: "ALL"
    property string selectedNotebookLabel: I18n.tr("all_notes")
    property string selectedFolder: "ALL"
    property string selectedFolderLabel: I18n.tr("all_notes")
    property bool isSearching: searchField.text.trim().length > 0 || searchField.activeFocus

    // Safely reload state when swiping or returning to this page
    onStatusChanged: {
        if (status === PageStatus.Active) {
            page.currentLanguage = I18n.currentLang || "en";

            if (py && py.ready) {
                py.refreshActiveNotebook();
                py.loadNotebooks();
            }
        }
    }

    // Resets search and filter parameters back to default/active state
    function resetSearchFilters() {
        if (page.activeNotebookName !== "") {
            page.selectedNotebook = page.activeNotebookName
            page.selectedNotebookLabel = page.activeNotebookName
        } else {
            page.selectedNotebook = "ALL"
            page.selectedNotebookLabel = I18n.tr("all_notes")
        }
        page.selectedFolder = "ALL"
        page.selectedFolderLabel = I18n.tr("all_notes")

        if (py && py.ready) {
            py.loadFoldersForNotebook(page.selectedNotebook)
        }
    }

    // Cancels search mode and clears inputs
    function cancelSearch() {
        searchField.text = ""
        searchField.focus = false
        resetSearchFilters()
    }

    // Data models
    ListModel { id: notebooksModel }
    ListModel { id: filterNotebooksModel }
    ListModel { id: filterFoldersModel }
    ListModel { id: searchResultsModel }

    // Python bridge for backend operations
    Python {
        id: py
        property bool ready: false

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../"))
            importModule("nb_backend", function() {
                py.ready = true
                py.refreshActiveNotebook()
                py.loadNotebooks()
            })
        }

        // Fetches active notebook from Python backend
        function refreshActiveNotebook() {
            if (!ready) return;
            call("nb_backend.get_active_notebook", [], function(active) {
                if (active) {
                    page.activeNotebookName = active
                } else {
                    page.activeNotebookName = ""
                }
                page.resetSearchFilters()
                py.loadFilterOptions()
            })
        }

        // Populates main list with notebooks (viser nå alle, inkludert quickNotes)
        function loadNotebooks() {
            if (!ready) return;
            call("nb_backend.get_notebooks", [], function(notebooks) {
                notebooksModel.clear()
                if (notebooks) {
                    for (var i = 0; i < notebooks.length; i++) {
                        notebooksModel.append({ "name": notebooks[i] })
                    }
                }
            })
        }

        // Populates filter options for notebooks search filter
        function loadFilterOptions() {
            if (!ready) return;
            call("nb_backend.get_notebooks", [], function(notebooks) {
                filterNotebooksModel.clear()
                filterNotebooksModel.append({ "name": "ALL", "label": I18n.tr("all_notes") })
                if (notebooks) {
                    for (var i = 0; i < notebooks.length; i++) {
                        filterNotebooksModel.append({ "name": notebooks[i], "label": notebooks[i] })
                    }
                }
            })
            py.loadFoldersForNotebook(page.selectedNotebook)
        }

        // Populates filter options for folders search filter
        function loadFoldersForNotebook(nbName) {
            if (!ready) return;
            call("nb_backend.get_folders", [nbName], function(folders) {
                filterFoldersModel.clear()
                filterFoldersModel.append({ "path": "ALL", "label": I18n.tr("all_notes") })
                if (folders) {
                    for (var j = 0; j < folders.length; j++) {
                        filterFoldersModel.append({ "path": folders[j], "label": folders[j] })
                    }
                }
            })
        }

        // Sets the active notebook
        function setActiveNotebook(nbName, callback) {
            if (!ready) return;
            call("nb_backend.set_active_notebook", [nbName], function(res) {
                if (res === "OK") {
                    page.activeNotebookName = nbName
                    page.resetSearchFilters()
                    py.loadFilterOptions()
                }
                if (callback) callback()
            })
        }

        // Deletes a notebook item
        function deleteNotebook(nbName) {
            if (!ready) return;
            call("nb_backend.delete_item", [nbName], function(res) {
                if (res === "OK" || res === "200") {
                    py.loadNotebooks()
                    py.refreshActiveNotebook()
                }
            })
        }

        // Executes query against search index
        function executeSearch(query) {
            if (!ready) return;
            if (query.trim().length === 0) {
                searchResultsModel.clear()
                return
            }

            call("nb_backend.search_notes", [query, page.selectedFolder, page.selectedNotebook], function(results) {
                searchResultsModel.clear()
                if (results) {
                    for (var i = 0; i < results.length; i++) {
                        searchResultsModel.append({
                            "title": results[i].title,
                            "path": results[i].path,
                            "snippet": results[i].snippet,
                            "extra_matches": results[i].extra_matches,
                            "total_matches": results[i].total_matches
                        })
                    }
                }
            })
        }
    }

    // --- MAIN CONTENT: NOTEBOOKS ---
    SilicaListView {
        id: mainListView
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: searchPanel.top
        visible: !page.isSearching
        clip: true
        model: notebooksModel

        PullDownMenu {
            MenuItem {
                text: page.currentLanguage ? I18n.tr("create_notebook") : ""
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("CreateNotebookDialog.qml"))
                    dialog.accepted.connect(function() {
                        var nbName = dialog.notebookName ? dialog.notebookName.trim() : ""
                        if (nbName.length > 0 && py && py.ready) {
                            py.call("nb_backend.create_notebook", [nbName], function(success) {
                                if (success) {
                                    py.loadNotebooks();
                                    py.refreshActiveNotebook();
                                }
                            })
                        }
                    })
                }
            }

            MenuItem {
                text: page.currentLanguage ? I18n.tr("create_folder") : ""
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("CreateFolderDialog.qml"))
                    dialog.accepted.connect(function() {
                        var folderName = (dialog.folderName || dialog.inputValue || "").trim()
                        if (folderName.length > 0 && py.ready) {
                            py.call("nb_backend.create_folder", [folderName, page.activeNotebookName], function(success) {
                                if (success) {
                                    py.loadFoldersForNotebook(page.selectedNotebook)
                                }
                            })
                        }
                    })
                }
            }

            MenuItem {
                text: page.currentLanguage ? I18n.tr("create_note") : ""
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("CreateNoteDialog.qml"), { "python": py })
                    dialog.accepted.connect(function() {
                        var content = dialog.noteContent ? dialog.noteContent.trim() : ""
                        var folder = dialog.selectedFolder

                        if (content.length > 0 && py.ready) {
                            py.call("nb_backend.create_note", [content, folder], function(success) {
                                if (success) {
                                    py.loadNotebooks()
                                }
                            })
                        }
                    })
                }
            }

            MenuItem {
                text: page.currentLanguage ? I18n.tr("all_notes") : ""
                onClicked: pageStack.push(Qt.resolvedUrl("AllNotesPage.qml"))
            }
        }

        header: PageHeader {
            title: page.currentLanguage ? I18n.tr("notebooks") : ""
            description: page.activeNotebookName !== ""
                         ? (page.currentLanguage ? I18n.tr("active_notebook") : "") + ": " + page.activeNotebookName
                         : ""
        }

        delegate: ListItem {
            id: delegate
            width: mainListView.width
            contentHeight: Theme.itemSizeMedium

            menu: ContextMenu {
                MenuItem {
                    text: page.currentLanguage ? I18n.tr("choose_notebook") : ""
                    onClicked: {
                        if (py.ready) py.setActiveNotebook(model.name, null)
                    }
                }

                MenuItem {
                    text: page.currentLanguage ? I18n.tr("delete_notebook") : ""
                    onClicked: {
                        var nbName = model.name;
                        delegate.remorseAction((page.currentLanguage ? I18n.tr("delete") : "") + " " + nbName, function() {
                            if (py.ready) py.deleteNotebook(nbName);
                        });
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Label {
                    text: "📁"
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: model.name + (model.name === page.activeNotebookName ? " (" + (page.currentLanguage ? I18n.tr("active_notebook") : "") + ")" : "")
                    font.bold: model.name === page.activeNotebookName
                    font.pixelSize: Theme.fontSizeMedium
                    color: delegate.highlighted ? Theme.highlightColor : (model.name === page.activeNotebookName ? Theme.highlightColor : Theme.primaryColor)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium
                    truncationMode: TruncationMode.Elide
                }
            }

            onClicked: {
                if (py.ready) {
                    py.setActiveNotebook(model.name, function() {
                        pageStack.push(Qt.resolvedUrl("AllNotesPage.qml"))
                    })
                }
            }
        }

        VerticalScrollDecorator {}
    }

    // --- SEARCH PANEL SECTION ---
    Item {
        id: searchPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: page.isSearching ? parent.top : undefined
        height: page.isSearching ? undefined : searchRow.height + Theme.paddingSmall

        Rectangle {
            anchors.fill: parent
            color: Theme.rgba(Theme.overlayBackgroundColor, 0.98)
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: searchRow.top
            visible: page.isSearching

            PageHeader {
                title: page.currentLanguage ? I18n.tr("search_notes") : ""
            }

            // Notebook filter dropdown
            ListItem {
                id: notebookFilterItem
                width: parent.width
                contentHeight: Theme.itemSizeSmall

                menu: ContextMenu {
                    Repeater {
                        model: filterNotebooksModel
                        MenuItem {
                            text: model.label
                            onClicked: {
                                page.selectedNotebook = model.name
                                page.selectedNotebookLabel = model.label

                                page.selectedFolder = "ALL"
                                page.selectedFolderLabel = page.currentLanguage ? I18n.tr("all_notes") : ""

                                if (py.ready) {
                                    py.loadFoldersForNotebook(model.name)
                                    py.executeSearch(searchField.text)
                                }
                            }
                        }
                    }
                }

                ValueButton {
                    label: (page.currentLanguage ? I18n.tr("notebooks") : "") + ":"
                    value: page.selectedNotebookLabel
                    anchors.fill: parent
                    enabled: false
                }

                onClicked: openMenu()
            }

            // Folder filter dropdown
            ListItem {
                id: folderFilterItem
                width: parent.width
                contentHeight: Theme.itemSizeSmall

                menu: ContextMenu {
                    Repeater {
                        model: filterFoldersModel
                        MenuItem {
                            text: model.label
                            onClicked: {
                                page.selectedFolder = model.path
                                page.selectedFolderLabel = model.label
                                if (py.ready) py.executeSearch(searchField.text)
                            }
                        }
                    }
                }

                ValueButton {
                    label: (page.currentLanguage ? I18n.tr("folder") : "") + ":"
                    value: page.selectedFolderLabel
                    anchors.fill: parent
                    enabled: false
                }

                onClicked: openMenu()
            }

            SilicaListView {
                width: parent.width
                height: parent.height - y
                clip: true
                model: searchResultsModel

                header: SectionHeader {
                    text: searchResultsModel.count > 0
                          ? (page.currentLanguage ? I18n.tr("hits") : "") + " (" + searchResultsModel.count + ")"
                          : (searchField.text.length > 0 ? "0 " + (page.currentLanguage ? I18n.tr("hits") : "") : (page.currentLanguage ? I18n.tr("type_to_search") : ""))
                }

                delegate: ListItem {
                    id: searchDelegate
                    width: parent.width
                    contentHeight: searchColumn.height + Theme.paddingMedium * 2

                    menu: ContextMenu {
                        MenuItem {
                            text: page.currentLanguage ? I18n.tr("delete_note") : ""
                            onClicked: {
                                var notePath = model.path
                                searchDelegate.remorseAction((page.currentLanguage ? I18n.tr("delete") : "") + " " + model.title, function() {
                                    if (py.ready) {
                                        py.call("nb_backend.delete_item", [notePath], function(res) {
                                            py.executeSearch(searchField.text)
                                        })
                                    }
                                })
                            }
                        }
                    }

                    Column {
                        id: searchColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingSmall

                        Label {
                            text: model.title
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            color: searchDelegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                            width: parent.width
                            truncationMode: TruncationMode.Elide
                        }

                        Label {
                            text: model.snippet
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryHighlightColor
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                        }

                        Row {
                            width: parent.width

                            Label {
                                text: "📂 " + model.path
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                width: parent.width * 0.6
                                truncationMode: TruncationMode.Elide
                            }

                            Label {
                                text: model.extra_matches > 0 ? "+" + model.extra_matches + " " + (page.currentLanguage ? I18n.tr("hits") : "") : ""
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                horizontalAlignment: Text.AlignRight
                                width: parent.width * 0.4
                            }
                        }
                    }

                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("NoteShowPage.qml"), {
                            "noteId": model.path,
                            "python": py
                        })
                    }
                }

                VerticalScrollDecorator {}
            }
        }

        Row {
            id: searchRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            TextField {
                id: searchField
                width: page.isSearching ? parent.width - cancelSearchBtn.width : parent.width
                placeholderText: page.currentLanguage ? I18n.tr("search_placeholder") : ""
                labelVisible: false

                onTextChanged: {
                    if (py && py.ready) {
                        py.executeSearch(text)
                    }
                }
            }

            IconButton {
                id: cancelSearchBtn
                icon.source: "image://theme/icon-m-clear"
                visible: page.isSearching
                anchors.verticalCenter: searchField.verticalCenter
                onClicked: page.cancelSearch()
            }
        }
    }
}
