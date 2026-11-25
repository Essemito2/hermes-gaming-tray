// hermes-gaming-tray — notification area applet.
// Derived from Scriptinator (GPL-3.0-or-later, tubbadu) — same "executable"
// DataSource pattern with markers on stdout; simplified here: no custom
// configuration beyond the settings tab, double click = toggle,
// right click = contextual menu (Plasmoid.contextualActions) plus the
// "Configure..." entry added by the shell.
import QtQuick
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    // Icon/tooltip state (updated by hg-state.sh via markers).
    // Empty at startup: the first data arrives right away; while empty the
    // icon is hidden to avoid a white placeholder.
    property string iconPath: ""
    property string tipHead: "Hermes Gaming"
    property string tipBody: "Gaming mode: waiting..."
    property string status: "passive"
    property bool busy: false
    // effective auto-off flag (1/0 from the hg-state.sh marker; true if absent)
    property bool autoOffEnabled: true

    // Commands: helper scripts shipped inside the applet package
    // plasmashell resolves relative URLs to file:// URIs, but the
    // executable engine hands the string to /bin/sh: a plain
    // filesystem path is required.
    function toPath(u: string): string {
        return u.startsWith("file://") ? u.slice(7) : u
    }

    readonly property string statusCmd: toPath(Qt.resolvedUrl("hg-state.sh"))
    readonly property string toggleCmd: toPath(Qt.resolvedUrl("hg-toggle.sh"))
    // persistent auto-off flag toggle (0 = disabled, 1 = enabled)
    readonly property string autooffCmdBase: toPath(Qt.resolvedUrl("hg-set-autooff.sh"))

    // Common entry point for the double click and the Enable/Disable menu entry
    function toggle() {
        if (root.busy) {
            return
        }
        root.busy = true
        root.tipBody = "Gaming mode: toggling..."
        executable.exec(root.toggleCmd)
    }

    // Toggles the persistent auto-off flag (also updates the active session right away)
    function setAutooff(enabled) {
        if (root.busy) {
            return
        }
        root.busy = true
        root.tipBody = "Gaming mode: updating auto-off..."
        executable.exec(root.autooffCmdBase + (enabled ? " 1" : " 0"))
    }

    Component.onCompleted: {
        executable.exec(root.statusCmd)
    }

    onStatusChanged: {
        // same mapping as Scriptinator
        let getStatusCode = {
            "active": PlasmaCore.Types.ActiveStatus,
            "passive": PlasmaCore.Types.PassiveStatus,
            "attention": PlasmaCore.Types.NeedsAttentionStatus,
            "hidden": PlasmaCore.Types.Hidden
        }
        let newStatus = getStatusCode[root.status.toLowerCase()]
        if (newStatus === undefined) {
            newStatus = getStatusCode["active"]
        }
        plasmoid.status = newStatus
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var exitCode = data["exit code"]
            var exitStatus = data["exit status"]
            var stdout = data["stdout"]
            var stderr = data["stderr"]
            exited(sourceName, exitCode, exitStatus, stdout, stderr)
            disconnectSource(sourceName) // cmd finished
        }

        function exec(cmd) {
            if (cmd) {
                connectSource(cmd)
            }
        }

        signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)
    }

    Connections {
        target: executable

        function extractFromTags(text, tag1, tag2) {
            const regex = new RegExp(tag1 + "(.*)" + tag2, "g");
            const matches = text.match(regex);
            if (matches) {
                return matches.map(match => match.replace(tag1, '').replace(tag2, ''));
            }
            return [];
        }

        function onExited(cmd, exitCode, exitStatus, stdout, stderr) {
            // slice(-1) takes the last one (Scriptinator pattern)
            let icon = extractFromTags(stdout, "{IconStart}", "{IconEnd}").slice(-1)[0];
            let tipHead = extractFromTags(stdout, "{TipHeadStart}", "{TipHeadEnd}").slice(-1)[0];
            let tipBody = extractFromTags(stdout, "{TipBodyStart}", "{TipBodyEnd}").slice(-1)[0];
            let status = extractFromTags(stdout, "{StatusStart}", "{StatusEnd}").slice(-1)[0];
            let autoOff = extractFromTags(stdout, "{AutoOffStart}", "{AutoOffEnd}").slice(-1)[0];

            if (icon) {
                root.iconPath = icon.trim();
            }
            if (tipHead) {
                root.tipHead = tipHead;
            }
            if (tipBody) {
                root.tipBody = tipBody;
            }
            if (status) {
                root.status = status.trim();
            }
            if (autoOff !== undefined && autoOff !== "") {
                root.autoOffEnabled = autoOff.trim() === "1";
            }

            // after a toggle (which can take ~60s with "on") or an auto-off
            // flag update, re-read the state
            if (cmd === root.toggleCmd || cmd.indexOf(root.autooffCmdBase) === 0) {
                root.busy = false
                executable.exec(root.statusCmd)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton // the right button goes to the plasmashell menu (with our actions)
        onDoubleClicked: {
            // Settings tab flag (main.xml "doubleClickToggle", default true):
            // undefined means "not saved yet" and counts as enabled.
            if (Plasmoid.configuration.doubleClickToggle !== false) {
                root.toggle()
            }
        }
    }

    Kirigami.Icon {
        anchors.fill: parent
        anchors.margins: 2
        // source must be an absolute path (relative ones are resolved against
        // plasmashell's CWD, not against the QML document)
        source: root.iconPath
        // JS string: use .length (.isEmpty() does not exist on QML strings)
        visible: root.iconPath.length > 0
        smooth: true
        fallback: "input-gamepad"

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            timeout: -1
            mainText: root.tipHead
            subText: root.tipBody
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: {
            // light poll: keeps the icon up to date with external changes
            // (e.g. the scheduled auto-off)
            if (!root.busy) {
                executable.exec(root.statusCmd)
            }
        }
    }

    // Contextual menu (right click in the system tray): our actions come
    // before the "Configure..." entry the shell always adds.
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            // text/icon follow the current state
            text: root.status === "active" ? "Disable gaming mode" : "Enable gaming mode"
            icon.name: root.status === "active" ? "media-eject-symbolic" : "media-playback-start-symbolic"
            enabled: !root.busy
            onTriggered: root.toggle()
        },
        PlasmaCore.Action {
            // text/icon follow the auto-off flag state
            text: root.autoOffEnabled ? "Disable auto-off" : "Enable auto-off"
            icon.name: root.autoOffEnabled ? "media-eject-symbolic" : "media-playback-start-symbolic"
            enabled: !root.busy
            onTriggered: root.setAutooff(!root.autoOffEnabled)
        },
        PlasmaCore.Action {
            isSeparator: true
        }
    ]

    Plasmoid.icon: "input-gamepad"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
}
