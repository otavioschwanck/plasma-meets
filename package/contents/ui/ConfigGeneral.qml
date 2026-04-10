import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: configPage

    property int cfg_daysAhead:       plasmoid.configuration.daysAhead
    property int cfg_notifyMinutes:   plasmoid.configuration.notifyMinutes
    property int cfg_syncIntervalMin: plasmoid.configuration.syncIntervalMin

    implicitHeight: form.implicitHeight + Kirigami.Units.largeSpacing * 2

    QtObject {
        id: deviceFlow
        property bool   active:          false
        property string userCode:        ""
        property string verificationUrl: ""
        property string deviceCode:      ""
        property string errorMsg:        ""

        function start() {
            errorMsg = ""
            var id = plasmoid.configuration.clientId
            if (!id) { errorMsg = "Enter Client ID first."; return }
            var xhr = new XMLHttpRequest()
            xhr.open("POST", "https://oauth2.googleapis.com/device/code")
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200) {
                    var d = JSON.parse(xhr.responseText)
                    deviceFlow.deviceCode      = d.device_code
                    deviceFlow.userCode        = d.user_code
                    deviceFlow.verificationUrl = d.verification_url || "https://www.google.com/device"
                    deviceFlow.active          = true
                    pollTimer.interval         = (d.interval || 5) * 1000
                    pollTimer.start()
                } else {
                    var msg = "Error " + xhr.status
                    try {
                        var e = JSON.parse(xhr.responseText)
                        if (e.error) msg += ": " + e.error
                        if (e.error_description) msg += " — " + e.error_description
                    } catch(_) {}
                    if (xhr.status === 401 || xhr.status === 403)
                        msg += "\nCredential type must be \"TVs and limited input devices\"."
                    deviceFlow.errorMsg = msg
                }
            }
            xhr.send("client_id=" + encodeURIComponent(id) +
                     "&scope=https://www.googleapis.com/auth/calendar.readonly")
        }

        function stop() {
            active = false; deviceCode = ""; pollTimer.stop()
        }
    }

    Timer {
        id: pollTimer
        repeat: true; running: false
        onTriggered: {
            var xhr = new XMLHttpRequest()
            xhr.open("POST", "https://oauth2.googleapis.com/token")
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                var d = JSON.parse(xhr.responseText)
                if (d.access_token) {
                    plasmoid.configuration.accessToken  = d.access_token
                    plasmoid.configuration.refreshToken = d.refresh_token
                    plasmoid.configuration.tokenExpiry  = String(Math.floor(Date.now() / 1000) + d.expires_in - 60)
                    var exhr = new XMLHttpRequest()
                    exhr.open("GET", "https://www.googleapis.com/oauth2/v2/userinfo")
                    exhr.setRequestHeader("Authorization", "Bearer " + d.access_token)
                    exhr.onreadystatechange = function() {
                        if (exhr.readyState !== XMLHttpRequest.DONE) return
                        if (exhr.status === 200) {
                            var u = JSON.parse(exhr.responseText)
                            plasmoid.configuration.accountEmail = u.email || u.name || ""
                        }
                    }
                    exhr.send()
                    deviceFlow.stop()
                } else if (d.error && d.error !== "authorization_pending") {
                    deviceFlow.stop()
                }
            }
            xhr.send("client_id="      + encodeURIComponent(plasmoid.configuration.clientId) +
                     "&client_secret=" + encodeURIComponent(plasmoid.configuration.clientSecret) +
                     "&device_code="   + encodeURIComponent(deviceFlow.deviceCode) +
                     "&grant_type=urn:ietf:params:oauth:grant-type:device_code")
        }
    }

    Kirigami.FormLayout {
        id: form
        anchors { top: parent.top; left: parent.left; right: parent.right }

        Kirigami.Separator { Kirigami.FormData.label: i18n("Google Account") }

        // Connected
        RowLayout {
            visible: plasmoid.configuration.accessToken !== ""
            Kirigami.FormData.label: ""
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon { source: "user-online"; width: Kirigami.Units.iconSizes.small; height: width }
            QQC2.Label { text: plasmoid.configuration.accountEmail || i18n("Connected"); font.bold: true }
            Item { width: Kirigami.Units.gridUnit }
            QQC2.Button {
                text: i18n("Disconnect")
                onClicked: {
                    plasmoid.configuration.accessToken  = ""
                    plasmoid.configuration.refreshToken = ""
                    plasmoid.configuration.tokenExpiry  = "0"
                    plasmoid.configuration.accountEmail = ""
                }
            }
        }

        // Client ID
        QQC2.TextField {
            id: clientIdField
            visible: plasmoid.configuration.accessToken === ""
            Kirigami.FormData.label: i18n("Client ID:")
            placeholderText: "OAuth2 Client ID"
            text: plasmoid.configuration.clientId
            onEditingFinished: plasmoid.configuration.clientId = text
            implicitWidth: Kirigami.Units.gridUnit * 22
        }

        // Client Secret
        QQC2.TextField {
            id: clientSecretField
            visible: plasmoid.configuration.accessToken === ""
            Kirigami.FormData.label: i18n("Client Secret:")
            placeholderText: "OAuth2 Client Secret"
            text: plasmoid.configuration.clientSecret
            echoMode: TextInput.Password
            onEditingFinished: plasmoid.configuration.clientSecret = text
            implicitWidth: Kirigami.Units.gridUnit * 22
        }

        // Instructions
        QQC2.Label {
            visible: plasmoid.configuration.accessToken === ""
            Kirigami.FormData.label: ""
            text: i18n("In Google Cloud Console: enable Calendar API, create an OAuth client ID with type \"TVs and limited input devices\".")
            wrapMode: Text.WordWrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        // Cloud Console link button
        QQC2.Button {
            visible: plasmoid.configuration.accessToken === ""
            Kirigami.FormData.label: ""
            text: i18n("Open Google Cloud Console →")
            icon.name: "internet-web-browser"
            onClicked: Qt.openUrlExternally("https://console.cloud.google.com/apis/credentials")
        }

        // Error
        QQC2.Label {
            visible: plasmoid.configuration.accessToken === "" && deviceFlow.errorMsg !== ""
            Kirigami.FormData.label: ""
            text: deviceFlow.errorMsg
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        // Connect button
        QQC2.Button {
            visible: plasmoid.configuration.accessToken === "" && !deviceFlow.active
            Kirigami.FormData.label: ""
            text: i18n("Connect Google Account")
            icon.name: "user-online"
            enabled: clientIdField.text !== "" && clientSecretField.text !== ""
            onClicked: {
                plasmoid.configuration.clientId     = clientIdField.text
                plasmoid.configuration.clientSecret = clientSecretField.text
                deviceFlow.start()
            }
        }

        // ── Device flow ───────────────────────────────────────────────────────
        Kirigami.Separator {
            visible: deviceFlow.active
            Kirigami.FormData.label: i18n("Authorization")
        }

        QQC2.Label {
            visible: deviceFlow.active
            Kirigami.FormData.label: i18n("Step 1:")
            text: i18n("Visit %1", deviceFlow.verificationUrl)
        }

        QQC2.Button {
            visible: deviceFlow.active
            Kirigami.FormData.label: ""
            text: deviceFlow.verificationUrl
            icon.name: "internet-web-browser"
            onClicked: Qt.openUrlExternally(deviceFlow.verificationUrl)
        }

        QQC2.Label {
            visible: deviceFlow.active
            Kirigami.FormData.label: i18n("Step 2:")
            text: i18n("Enter this code:")
        }

        Rectangle {
            visible: deviceFlow.active
            Kirigami.FormData.label: ""
            implicitWidth:  codeLabel.implicitWidth  + Kirigami.Units.gridUnit * 2
            implicitHeight: codeLabel.implicitHeight + Kirigami.Units.largeSpacing
            radius: Kirigami.Units.cornerRadius
            color:  Kirigami.Theme.alternateBackgroundColor
            border.color: Kirigami.Theme.highlightColor
            border.width: 2

            QQC2.Label {
                id: codeLabel
                anchors.centerIn: parent
                text: deviceFlow.userCode
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
                font.bold: true
                font.family: "monospace"
                color: Kirigami.Theme.highlightColor
                letterSpacing: 2
            }
        }

        RowLayout {
            visible: deviceFlow.active
            Kirigami.FormData.label: ""
            spacing: Kirigami.Units.smallSpacing
            QQC2.BusyIndicator {
                running: deviceFlow.active
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                padding: 0
            }
            QQC2.Label {
                text: i18n("Waiting for authorization…")
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            QQC2.Button { text: i18n("Cancel"); onClicked: deviceFlow.stop() }
        }

        // ── Calendar ──────────────────────────────────────────────────────────
        Kirigami.Separator { Kirigami.FormData.label: i18n("Calendar") }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Days ahead:")
            from: 1; to: 30; value: cfg_daysAhead
            onValueChanged: cfg_daysAhead = value
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Notify before (min):")
            from: 1; to: 60; value: cfg_notifyMinutes
            onValueChanged: cfg_notifyMinutes = value
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Sync every (min):")
            from: 1; to: 60; value: cfg_syncIntervalMin
            onValueChanged: cfg_syncIntervalMin = value
        }
    }
}
