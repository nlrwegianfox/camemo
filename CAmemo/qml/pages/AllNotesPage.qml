import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.5
import "../i18n.js" as I18n

Page {
    id: page
    allowedOrientations: Orientation.All

    property var rawTree: []
    property var collapsedDirs: ({})
    property string currentLanguage: I18n.currentLang || "en"

    ListModel {
        id: treeModel
    }

    // Safely trigger data refresh when page becomes active, provided Python is ready
    onStatusChanged: {
        if (status === PageStatus.Active && py && py.ready) {
            refreshTree();
        }
    }

    // Rebuilds the visual tree structure in treeModel based on state and collapsing
    function updateVisibleModel() {
        treeModel.clear();

        for (var i = 0; i < rawTree.length; i++) {
            var item = rawTree[i];

            // 1. Root notebook item (level 0) is always visible
            if (item.level === 0) {
                treeModel.append(item);
                continue;
            }

            // 2. Subfolders at level 1 are always visible in the tree structure
            // regardless of whether the root folder is collapsed or expanded
            if (item.is_dir && item.level === 1) {
                treeModel.append(item);
                continue;
            }

            // 3. For files and deeper items: Check parent states, ignoring "dir:home_root"
            var currentParent = item.parent || "";
            var isVisible = true;

            // If it's a file directly inside the root folder (level 1 & parent = dir:home_root),
            // show it only if the root folder is expanded:
            if (!item.is_dir && item.parent === "dir:home_root") {
                if (page.collapsedDirs["dir:home_root"] === true) {
                    isVisible = false;
                }
            } else {
                // For nested files/folders: Check ancestry up to root
                while (currentParent !== "" && currentParent !== "dir:home_root") {
                    if (page.collapsedDirs[currentParent] === true) {
                        isVisible = false;
                        break;
                    }

                    // Find parent's parent in rawTree
                    var foundParent = null;
                    for (var j = 0; j < rawTree.length; j++) {
                        if (rawTree[j].id === currentParent) {
                            foundParent = rawTree[j];
                            break;
                        }
                    }
                    currentParent = foundParent ? (foundParent.parent || "") : "";
                }
            }

            if (isVisible) {
                treeModel.append(item);
            }
        }
    }

    // Fetches the file and folder tree hierarchy from Python backend
    function refreshTree() {
        if (!py || !py.ready) return;

        py.call("nb_backend.get_tree_structure", [], function(result) {
            page.rawTree = result || [];

            // All folders start in a collapsed state by default
            var initialCollapsed = {};
            for (var i = 0; i < page.rawTree.length; i++) {
                var item = page.rawTree[i];
                if (item.is_dir) {
                    initialCollapsed[item.id] = true;
                }
            }
            page.collapsedDirs = initialCollapsed;

            page.updateVisibleModel();
        })
    }

    onCollapsedDirsChanged: {
        updateVisibleModel();
    }

    Python {
        id: py
        property bool ready: false

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../"))
            importModule("nb_backend", function() {
                py.ready = true;
                page.refreshTree();
            })
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: treeModel

        PullDownMenu {
            id: pullDownMenu

            MenuItem {
                text: page.currentLanguage ? I18n.tr("create_note") : ""
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("CreateNoteDialog.qml"), {
                        "python": py
                    })

                    // Use standard Sailfish dialog signal handler
                    dialog.accepted.connect(function() {
                        var content = dialog.noteContent ? dialog.noteContent.trim() : ""
                        var folder = dialog.selectedFolder

                        if (content.length > 0 && py && py.ready) {
                            py.call("nb_backend.create_note", [content, folder], function(success) {
                                if (success) {
                                    page.refreshTree();
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
                        var folderName = dialog.inputValue ? dialog.inputValue.trim() : ""
                        if (folderName.length > 0 && py.ready) {
                            py.call("nb_backend.create_folder", [folderName], function(success) {
                                if (success) {
                                    page.refreshTree();
                                }
                            })
                        }
                    })
                }
            }
        }

        header: PageHeader {
            title: page.currentLanguage ? I18n.tr("all_notes") : ""
        }

        delegate: ListItem {
            id: delegate
            width: listView.width
            contentHeight: Theme.itemSizeSmall

            property bool isRootHome: (model.id === "dir:home_root" || model.id === "dir:home" || model.id === "home")
            property bool isNotebookItem: (model.is_notebook === true || model.type === "notebook" || (model.is_dir && model.level === 0))

            menu: isRootHome ? null : contextMenuComponent

            function deleteCurrentItem() {
                var itemId = model.id || model.path || model.title;
                var itemTitle = model.title;
                remorseAction((page.currentLanguage ? I18n.tr("delete") : "") + " " + itemTitle, function() {
                    if (py.ready) {
                        py.call("nb_backend.delete_item", [itemId], function(res) {
                            page.refreshTree();
                        });
                    }
                });
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.horizontalPageMargin + (model.level * Theme.paddingLarge)
                anchors.rightMargin: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Label {
                    text: model.is_dir
                          ? (page.collapsedDirs[model.id] === true ? "📁 ▶" : "📂 ▼")
                          : "📄"
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: model.title
                    font.bold: model.is_dir
                    font.pixelSize: Theme.fontSizeMedium
                    color: delegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium
                    truncationMode: TruncationMode.Elide
                }
            }

            onClicked: {
                var isDirectory = (model.is_dir === true || model.is_dir === "true");

                if (isDirectory) {
                    var dirId = model.id;
                    var updated = {};

                    if (page.collapsedDirs) {
                        for (var key in page.collapsedDirs) {
                            updated[key] = page.collapsedDirs[key];
                        }
                    }

                    if (updated[dirId] === true) {
                        delete updated[dirId];
                    } else {
                        updated[dirId] = true;
                    }
                    page.collapsedDirs = updated;
                } else {
                    pageStack.push(Qt.resolvedUrl("NoteShowPage.qml"), {
                        "noteId": model.id,
                        "noteTitle": model.title,
                        "python": py
                    });
                }
            }

            Component {
                id: contextMenuComponent
                ContextMenu {
                    MenuItem {
                        text: delegate.isNotebookItem
                              ? (page.currentLanguage ? I18n.tr("delete_notebook") : "")
                              : (model.is_dir
                                 ? (page.currentLanguage ? I18n.tr("delete_folder") : "")
                                 : (page.currentLanguage ? I18n.tr("delete_note") : ""))
                        onClicked: delegate.deleteCurrentItem()
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
