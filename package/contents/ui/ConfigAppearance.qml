import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: configPage

    property int cfg_daysAhead:           7
    property int cfg_notifyMinutes:       10
    property int cfg_syncIntervalMin:     5
    property string cfg_taskbarMode:   Plasmoid.configuration.taskbarMode
    property int    cfg_titleMaxChars: Plasmoid.configuration.titleMaxChars
    property string cfg_iconNoMeet:    Plasmoid.configuration.iconNoMeet
    property string cfg_iconHasMeet:   Plasmoid.configuration.iconHasMeet

    property int cfg_daysAheadDefault:       7
    property int cfg_notifyMinutesDefault:   10
    property int cfg_syncIntervalMinDefault: 5
    property string cfg_taskbarModeDefault:  "time"
    property int cfg_titleMaxCharsDefault:   30
    property string cfg_iconNoMeetDefault:   "meeting-organizer"
    property string cfg_iconHasMeetDefault:  "meeting-attending"

    KIconThemes.IconDialog {
        id: iconDialog
        property string target: ""
        onIconNameChanged: iconName => {
            if (!iconName) return
            if (target === "noMeet")
                cfg_iconNoMeet = iconName
            else if (target === "hasMeet")
                cfg_iconHasMeet = iconName
        }
    }

    component IconPickerRow: RowLayout {
        property string label: ""
        property string iconName: ""
        property string targetKey: ""
        property string defaultIcon: ""

        Kirigami.FormData.label: label
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: iconName || defaultIcon
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        }

        QQC2.Label {
            text: iconName.length > 0 ? iconName : i18n("(default)")
            opacity: 0.7
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        QQC2.Button {
            text: i18n("Choose…")
            icon.name: "document-open"
            onClicked: {
                iconDialog.target = targetKey
                iconDialog.open()
            }
        }

        QQC2.Button {
            icon.name: "edit-undo"
            enabled: iconName !== defaultIcon
            onClicked: {
                if (targetKey === "noMeet")
                    cfg_iconNoMeet = defaultIcon
                else if (targetKey === "hasMeet")
                    cfg_iconHasMeet = defaultIcon
            }
            QQC2.ToolTip.text: i18n("Reset to default")
            QQC2.ToolTip.visible: hovered
        }
    }

    Kirigami.FormLayout {
        id: form

        // ── Taskbar ───────────────────────────────────────────────────────────
        Kirigami.Separator { Kirigami.FormData.label: i18n("Taskbar") }

        QQC2.ComboBox {
            id: modeCombo
            Kirigami.FormData.label: i18n("Show in taskbar:")
            model: [i18n("Icon only"), i18n("Time"), i18n("Time + Title")]
            currentIndex: ["icon", "time", "time+title"].indexOf(cfg_taskbarMode)
            onActivated: cfg_taskbarMode = ["icon", "time", "time+title"][currentIndex]
        }

        QQC2.SpinBox {
            id: charsSpinBox
            Kirigami.FormData.label: i18n("Title character limit:")
            visible: cfg_taskbarMode === "time+title"
            from: 5; to: 100
            value: cfg_titleMaxChars
            onValueChanged: cfg_titleMaxChars = value
        }

        // ── Icons ─────────────────────────────────────────────────────────────
        Kirigami.Separator { Kirigami.FormData.label: i18n("Icons") }

        IconPickerRow {
            label: i18n("No meetings today:")
            iconName: cfg_iconNoMeet
            targetKey: "noMeet"
            defaultIcon: "meeting-organizer"
        }

        IconPickerRow {
            label: i18n("Has meetings today:")
            iconName: cfg_iconHasMeet
            targetKey: "hasMeet"
            defaultIcon: "meeting-attending"
        }

        QQC2.Label {
            text: i18n("Choose icons using the standard Plasma icon picker.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
