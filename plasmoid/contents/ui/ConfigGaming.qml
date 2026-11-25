/*
    hermes-gaming-tray — "Gaming" settings tab: auto-off hour and flag.
    Derived from Scriptinator (GPL-3.0-or-later, tubbadu): "executable"
    DataSource with markers on stdout (same pattern as main.qml).
    License: GPL-3.0-or-later
*/
import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    // plasmashell resolves relative URLs to file:// URIs, but the
    // executable engine hands the string to /bin/sh: a plain
    // filesystem path is required.
    function toPath(u: string): string {
        return u.startsWith("file://") ? u.slice(7) : u
    }

    readonly property string setHourCmd: toPath(Qt.resolvedUrl("hg-set-offhour.sh"))
    readonly property string currentHourCmd: toPath(Qt.resolvedUrl("hg-current-offhour.sh"))
    readonly property string setAutoOffCmd: toPath(Qt.resolvedUrl("hg-set-autooff.sh"))

    // Result of the last apply (filled from the script markers)
    property string applyStatus: ""
    property bool applyOk: false

    // Re-entry guard: true while the prefill writes the SpinBox
    property bool prefilling: false
    // Re-entry guard: true while the prefill writes the CheckBox
    property bool prefillingAutoOff: false
    // Set script currently in flight
    property bool setRunning: false
    // Hour to apply (debounced)
    property int desiredHour: -1
    // Auto-off flag to apply (debounced); null = nothing queued
    property var desiredAutoOff: null

    // Pattern taken from main.qml: extracts the values between markers from stdout
    function extractFromTags(text, tag1, tag2) {
        const regex = new RegExp(tag1 + "(.*)" + tag2, "g");
        const matches = text.match(regex);
        if (matches) {
            return matches.map(match => match.replace(tag1, '').replace(tag2, ''));
        }
        return [];
    }

    // Issues the queued sets (after debounce): hour and/or auto-off flag
    function issueSets() {
        if (root.desiredHour >= 0) {
            let h = root.desiredHour
            root.desiredHour = -1
            Plasmoid.configuration.offHour = h
            execSrc.exec(root.setHourCmd + " " + h)
        }
        if (root.desiredAutoOff !== null) {
            let v = root.desiredAutoOff ? 1 : 0
            root.desiredAutoOff = null
            Plasmoid.configuration.autoOff = v
            // --silent: the dialog already shows the result label, no notification
            execSrc.exec(root.setAutoOffCmd + " " + v + " --silent")
        }
    }

    // "executable" runs the source as a shell command (setShellCommand):
    // arguments in the source name are supported.
    Plasma5Support.DataSource {
        id: execSrc
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var exitCode = data["exit code"]
            var stdout = data["stdout"]
            var stderr = data["stderr"]
            exited(sourceName, exitCode, stdout, stderr)
            disconnectSource(sourceName)
        }

        function exec(cmd) {
            if (cmd) {
                connectSource(cmd)
            }
        }

        signal exited(string cmd, int exitCode, string stdout, string stderr)
    }

    // Debounce: coalesces consecutive stepper changes
    Timer {
        id: setDebounceTimer
        interval: 400
        repeat: false
        onTriggered: root.issueSets()
    }

    // Safety net: the set result must not be left hanging
    Timer {
        id: setTimeoutTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (root.setRunning) {
                root.setRunning = false
                root.applyStatus = i18n("Warning: result not confirmed. The script was launched: check with 'hermes-gaming offhour'")
                root.applyOk = false
            }
        }
    }

    Connections {
        target: execSrc

        function onExited(cmd, exitCode, stdout, stderr) {
            if (cmd === root.currentHourCmd) {
                // System state: prefill the SpinBox (+ align the configuration)
                let h = extractFromTags(stdout, "{CurHourStart}", "{CurHourEnd}").slice(-1)[0]
                if (h !== undefined) {
                    let v = parseInt(String(h).trim(), 10)
                    if (!isNaN(v)) {
                        root.prefilling = true
                        if (hourSpin.value !== v) {
                            hourSpin.value = v
                        }
                        if (Plasmoid.configuration.offHour !== v) {
                            Plasmoid.configuration.offHour = v
                        }
                        root.prefilling = false
                    }
                }
                // System state: prefill the auto-off CheckBox
                let ao = extractFromTags(stdout, "{CurAutoOffStart}", "{CurAutoOffEnd}").slice(-1)[0]
                if (ao !== undefined) {
                    let b = String(ao).trim() === "1"
                    root.prefillingAutoOff = true
                    if (autoOffCheck.checked !== b) {
                        autoOffCheck.checked = b
                    }
                    root.prefillingAutoOff = false
                }
            } else if (cmd.startsWith(root.setHourCmd) || cmd.startsWith(root.setAutoOffCmd)) {
                root.setRunning = false
                setTimeoutTimer.stop()
                let ok = extractFromTags(stdout, "{SetHourStart}", "{SetHourEnd}").slice(-1)[0]
                if (ok === undefined) {
                    ok = extractFromTags(stdout, "{SetAutoOffStart}", "{SetAutoOffEnd}").slice(-1)[0]
                }
                let err = extractFromTags(stdout, "{ErrStart}", "{ErrEnd}").slice(-1)[0]
                if (ok !== undefined) {
                    root.applyStatus = ok.trim()
                    root.applyOk = true
                } else if (err !== undefined) {
                    root.applyStatus = err.trim()
                    root.applyOk = false
                } else {
                    root.applyStatus = i18n("Error (exit code %1)%2", exitCode, stderr ? "\n" + stderr : "")
                    root.applyOk = false
                }
            }
        }
    }

    Component.onCompleted: {
        execSrc.exec(root.currentHourCmd)
    }

    footer: Item {
        height: 60
    }

    Kirigami.FormLayout {
        SpinBox {
            id: hourSpin
            Kirigami.FormData.label: i18n("Turn off automatically at (hour 0-23)")
            Layout.fillWidth: true
            from: 0
            to: 23
            value: (Plasmoid.configuration.offHour === undefined) ? 0 : Plasmoid.configuration.offHour
            // the hour is meaningless if auto-off is disabled
            enabled: autoOffCheck.checked
            onValueChanged: {
                // The guard excludes the prefill; the debounce coalesces the stepper
                if (root.prefilling) {
                    return
                }
                root.desiredHour = hourSpin.value
                // Immediate feedback (the label has reserved space: no reflow)
                root.applyStatus = i18n("Applying...")
                root.applyOk = false
                root.setRunning = true
                setTimeoutTimer.restart()
                setDebounceTimer.restart()
            }
        }
        CheckBox {
            id: autoOffCheck
            Kirigami.FormData.label: i18n("Auto-off enabled")
            Layout.fillWidth: true
            checked: (Plasmoid.configuration.autoOff === undefined) ? true : (Plasmoid.configuration.autoOff !== 0)
            onCheckedChanged: {
                if (root.prefillingAutoOff) {
                    return
                }
                root.desiredAutoOff = autoOffCheck.checked
                root.applyStatus = i18n("Applying...")
                root.applyOk = false
                root.setRunning = true
                setTimeoutTimer.restart()
                setDebounceTimer.restart()
            }
        }
        // Result row: Item with fixed width (420 px) -> the longest normal
        // messages fit on one line and the width stays constant regardless
        // of the text (fixes the SpinBox width wobble).
        // Wrap is only a fallback for exceptional messages (timeout ~90
        // chars, long stderr): they go on a second line, otherwise one line.
        Item {
            id: statusHolder
            Layout.fillWidth: true
            implicitWidth: 420
            Label {
                id: statusLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                text: root.applyStatus
                wrapMode: Text.Wrap
                color: root.applyOk ? "#2e7d32" : "#c62828"
                // Space always reserved (opacity, not visible): no reflow/flicker
                opacity: root.applyStatus !== "" ? 1.0 : 0.0
            }
            implicitHeight: Math.max(22, statusLabel.implicitHeight)
        }
        // Local KConfig flag only (no script, no status row): main.qml reads
        // it on every double click, so there is nothing to prefill or apply.
        CheckBox {
            id: doubleClickCheck
            Kirigami.FormData.label: i18n("Toggle with double click")
            Layout.fillWidth: true
            checked: Plasmoid.configuration.doubleClickToggle === undefined
                ? true
                : Plasmoid.configuration.doubleClickToggle
            onCheckedChanged: {
                Plasmoid.configuration.doubleClickToggle = doubleClickCheck.checked
            }
        }
    }
}
