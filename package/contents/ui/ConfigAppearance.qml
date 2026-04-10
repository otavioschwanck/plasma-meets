import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: configPage

    property string cfg_clientId:         ""
    property string cfg_clientSecret:     ""
    property string cfg_accessToken:      ""
    property string cfg_refreshToken:     ""
    property string cfg_tokenExpiry:      "0"
    property string cfg_accountEmail:     ""
    property int cfg_daysAhead:           7
    property int cfg_notifyMinutes:       10
    property int cfg_syncIntervalMin:     5
    property string cfg_taskbarMode:   Plasmoid.configuration.taskbarMode
    property int    cfg_titleMaxChars: Plasmoid.configuration.titleMaxChars
    property string cfg_iconNoMeet:    Plasmoid.configuration.iconNoMeet
    property string cfg_iconHasMeet:   Plasmoid.configuration.iconHasMeet

    property string cfg_clientIdDefault:     ""
    property string cfg_clientSecretDefault: ""
    property string cfg_accessTokenDefault:  ""
    property string cfg_refreshTokenDefault: ""
    property string cfg_tokenExpiryDefault:  "0"
    property string cfg_accountEmailDefault: ""
    property int cfg_daysAheadDefault:       7
    property int cfg_notifyMinutesDefault:   10
    property int cfg_syncIntervalMinDefault: 5
    property string cfg_taskbarModeDefault:  "time"
    property int cfg_titleMaxCharsDefault:   30
    property string cfg_iconNoMeetDefault:   "meeting-organizer"
    property string cfg_iconHasMeetDefault:  "meeting-attending"

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

        RowLayout {
            Kirigami.FormData.label: i18n("No meetings today:")
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: iconNoMeetField.text || "meeting-organizer"
                width:  Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
            }
            QQC2.TextField {
                id: iconNoMeetField
                text: cfg_iconNoMeet || "meeting-organizer"
                placeholderText: "meeting-organizer"
                implicitWidth: Kirigami.Units.gridUnit * 14
                onTextChanged: cfg_iconNoMeet = text
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Has meetings today:")
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: iconHasMeetField.text || "meeting-attending"
                width:  Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
            }
            QQC2.TextField {
                id: iconHasMeetField
                text: cfg_iconHasMeet || "meeting-attending"
                placeholderText: "meeting-attending"
                implicitWidth: Kirigami.Units.gridUnit * 14
                onTextChanged: cfg_iconHasMeet = text
            }
        }

        QQC2.Label {
            text: i18n("Use KDE system icon names. Run 'kicondialog' to browse available icons.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
