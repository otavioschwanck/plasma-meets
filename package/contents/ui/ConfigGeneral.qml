import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: configPage

    property string cfg_clientId:         Plasmoid.configuration.clientId
    property string cfg_clientSecret:     Plasmoid.configuration.clientSecret
    property string cfg_accessToken:      Plasmoid.configuration.accessToken
    property string cfg_refreshToken:     Plasmoid.configuration.refreshToken
    property string cfg_tokenExpiry:      Plasmoid.configuration.tokenExpiry
    property string cfg_accountEmail:     Plasmoid.configuration.accountEmail
    property int cfg_authVersion:         Plasmoid.configuration.authVersion
    property int cfg_daysAhead:           Plasmoid.configuration.daysAhead
    property int cfg_notifyMinutes:       Plasmoid.configuration.notifyMinutes
    property int cfg_syncIntervalMin:     Plasmoid.configuration.syncIntervalMin
    property string cfg_taskbarMode:      Plasmoid.configuration.taskbarMode
    property int cfg_titleMaxChars:       Plasmoid.configuration.titleMaxChars
    property string cfg_iconNoMeet:       Plasmoid.configuration.iconNoMeet
    property string cfg_iconHasMeet:      Plasmoid.configuration.iconHasMeet

    property string cfg_clientIdDefault:     ""
    property string cfg_clientSecretDefault: ""
    property string cfg_accessTokenDefault:  ""
    property string cfg_refreshTokenDefault: ""
    property string cfg_tokenExpiryDefault:  "0"
    property string cfg_accountEmailDefault: ""
    property int cfg_authVersionDefault:     0
    property int cfg_daysAheadDefault:       7
    property int cfg_notifyMinutesDefault:   10
    property int cfg_syncIntervalMinDefault: 5
    property string cfg_taskbarModeDefault:  "time"
    property int cfg_titleMaxCharsDefault:   30
    property string cfg_iconNoMeetDefault:   "meeting-attending-tentative"
    property string cfg_iconHasMeetDefault:  "meeting-attending"
    property string clientSecretInput:       ""
    property bool hasRefreshToken:           false
    property bool hasClientSecret:           false
    readonly property bool isConnected:      hasRefreshToken

    TextEdit {
        id: clipboardProxy
        visible: false
    }

    QtObject {
        id: deviceFlow
        property bool   active:          false
        property string userCode:        ""
        property string verificationUrl: ""
        property string deviceCode:      ""
        property string errorMsg:        ""

        function trimmed(value) {
            return (value || "").trim()
        }

        function start() {
            errorMsg = ""
            var id = trimmed(configPage.cfg_clientId)
            configPage.cfg_clientId = id
            Plasmoid.configuration.clientId = id
            configPage.clientSecretInput = trimmed(configPage.clientSecretInput)
            if (!id) { errorMsg = i18n("Enter Client ID first."); return }
            if (!configPage.clientSecretInput) { errorMsg = i18n("Enter Client Secret first."); return }
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
                    var msg = i18n("Error %1", xhr.status)
                    try {
                        var e = JSON.parse(xhr.responseText)
                        if (e.error) msg += ": " + e.error
                        if (e.error_description) msg += " - " + e.error_description
                    } catch(_) {}
                    if (xhr.status === 401 || xhr.status === 403)
                        msg += "\n" + i18n("Check whether the Client ID was copied exactly and wait for Google to propagate the credential.")
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
            var clientId = deviceFlow.trimmed(configPage.cfg_clientId)
            var clientSecret = deviceFlow.trimmed(configPage.clientSecretInput)
            var xhr = new XMLHttpRequest()
            xhr.open("POST", "https://oauth2.googleapis.com/token")
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                var d = {}
                try {
                    d = JSON.parse(xhr.responseText)
                } catch (_) {}
                if (d.access_token) {
                    var refreshToken = d.refresh_token || ""
                    secureHelper.item.writeSecret("clientSecret", clientSecret)
                    if (refreshToken !== "")
                        secureHelper.item.writeSecret("refreshToken", refreshToken)
                    configPage.hasClientSecret = true
                    configPage.hasRefreshToken = refreshToken !== "" || configPage.hasRefreshToken
                    var exhr = new XMLHttpRequest()
                    exhr.open("GET", "https://www.googleapis.com/oauth2/v2/userinfo")
                    exhr.setRequestHeader("Authorization", "Bearer " + d.access_token)
                    exhr.onreadystatechange = function() {
                        if (exhr.readyState !== XMLHttpRequest.DONE) return
                        if (exhr.status === 200) {
                            var u = JSON.parse(exhr.responseText)
                            configPage.cfg_accountEmail = u.email || u.name || ""
                            Plasmoid.configuration.accountEmail = configPage.cfg_accountEmail
                        }
                    }
                    exhr.send()
                    configPage.clearLegacySecrets()
                    configPage.cfg_authVersion = configPage.cfg_authVersion + 1
                    Plasmoid.configuration.authVersion = configPage.cfg_authVersion
                    deviceFlow.stop()
                } else if (d.error === "authorization_pending") {
                    deviceFlow.errorMsg = ""
                } else if (d.error === "slow_down") {
                    pollTimer.interval = Math.max(pollTimer.interval + 5000, 10000)
                    deviceFlow.errorMsg = i18n("Google asked to slow down polling. Waiting a bit longer...")
                } else if (d.error) {
                    var msg = d.error
                    if (d.error_description)
                        msg += " - " + d.error_description
                    deviceFlow.errorMsg = msg
                    if (d.error === "access_denied"
                            || d.error === "expired_token"
                            || d.error === "invalid_client"
                            || d.error === "invalid_grant"
                            || d.error === "unauthorized_client") {
                        deviceFlow.stop()
                    }
                }
            }
            xhr.send("client_id="      + encodeURIComponent(clientId) +
                     "&client_secret=" + encodeURIComponent(clientSecret) +
                     "&device_code="   + encodeURIComponent(deviceFlow.deviceCode) +
                     "&grant_type=urn:ietf:params:oauth:grant-type:device_code")
        }
    }

    Loader {
        id: secureHelper
        active: true
        source: "SecureHelper.qml"
        onLoaded: configPage.loadStoredState()
    }

    function clearLegacySecrets() {
        if (Plasmoid.configuration.clientSecret !== "")
            Plasmoid.configuration.clientSecret = ""
        if (Plasmoid.configuration.accessToken !== "")
            Plasmoid.configuration.accessToken = ""
        if (Plasmoid.configuration.refreshToken !== "")
            Plasmoid.configuration.refreshToken = ""
        if (Plasmoid.configuration.tokenExpiry !== "0")
            Plasmoid.configuration.tokenExpiry = "0"
    }

    function loadStoredState() {
        if (!secureHelper.item)
            return
        secureHelper.item.readSecret("clientSecret", function(value) {
            configPage.hasClientSecret = value !== ""
        })
        secureHelper.item.readSecret("refreshToken", function(value) {
            configPage.hasRefreshToken = value !== ""
        })
    }

    function disconnectAccount() {
        if (!secureHelper.item)
            return
        secureHelper.item.readSecret("refreshToken", function(token) {
            if (token !== "")
                secureHelper.item.revokeToken(token)
            secureHelper.item.clearSecret("refreshToken")
            secureHelper.item.clearSecret("clientSecret")
            configPage.hasRefreshToken = false
            configPage.hasClientSecret = false
            configPage.clientSecretInput = ""
            configPage.cfg_accountEmail = ""
            Plasmoid.configuration.accountEmail = ""
            configPage.clearLegacySecrets()
            configPage.cfg_authVersion = configPage.cfg_authVersion + 1
            Plasmoid.configuration.authVersion = configPage.cfg_authVersion
        })
    }

    Component.onCompleted: {
        clearLegacySecrets()
        loadStoredState()
    }

    Kirigami.FormLayout {
        id: form
        Kirigami.Separator { Kirigami.FormData.label: i18n("Google Account") }

        // Connected
        RowLayout {
            visible: configPage.isConnected
            Kirigami.FormData.label: ""
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon { source: "user-online"; width: Kirigami.Units.iconSizes.small; height: width }
            QQC2.Label { text: configPage.cfg_accountEmail || i18n("Connected"); font.bold: true }
            Item { width: Kirigami.Units.gridUnit }
            QQC2.Button {
                text: i18n("Disconnect")
                onClicked: configPage.disconnectAccount()
            }
        }

        // Client ID
        QQC2.TextField {
            id: clientIdField
            visible: !configPage.isConnected
            Kirigami.FormData.label: i18n("Client ID:")
            placeholderText: i18n("OAuth2 Client ID")
            text: configPage.cfg_clientId
            onEditingFinished: {
                configPage.cfg_clientId = text
                Plasmoid.configuration.clientId = text.trim()
            }
            implicitWidth: Kirigami.Units.gridUnit * 22
        }

        // Client Secret
        QQC2.TextField {
            id: clientSecretField
            visible: !configPage.isConnected
            Kirigami.FormData.label: i18n("Client Secret:")
            placeholderText: i18n("OAuth2 Client Secret")
            text: configPage.clientSecretInput
            echoMode: TextInput.Password
            onEditingFinished: configPage.clientSecretInput = text
            implicitWidth: Kirigami.Units.gridUnit * 22
        }

        // Instructions
        QQC2.Label {
            visible: !configPage.isConnected
            Kirigami.FormData.label: ""
            text: i18n("In Google Cloud Console, enable Calendar API and create an OAuth client ID with type \"TVs and limited input devices\".")
            wrapMode: Text.WordWrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        QQC2.Label {
            visible: !configPage.isConnected
            Kirigami.FormData.label: ""
            text: i18n("Client Secret and refresh token are stored in KWallet instead of Plasma's plain-text applet config.")
            wrapMode: Text.WordWrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        // Cloud Console link button
        QQC2.Button {
            visible: !configPage.isConnected
            Kirigami.FormData.label: ""
            text: i18n("Open Google Cloud Console ->")
            icon.name: "internet-web-browser"
            onClicked: Qt.openUrlExternally("https://console.cloud.google.com/apis/credentials")
        }

        // Error
        QQC2.Label {
            visible: !configPage.isConnected && deviceFlow.errorMsg !== ""
            Kirigami.FormData.label: ""
            text: deviceFlow.errorMsg
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        // Connect button
        QQC2.Button {
            visible: !configPage.isConnected && !deviceFlow.active
            Kirigami.FormData.label: ""
            text: i18n("Connect Google Account")
            icon.name: "user-online"
            enabled: clientIdField.text !== "" && clientSecretField.text !== ""
            onClicked: {
                configPage.cfg_clientId      = clientIdField.text.trim()
                configPage.clientSecretInput = clientSecretField.text.trim()
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

        RowLayout {
            visible: deviceFlow.active
            Kirigami.FormData.label: ""
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.fillWidth: true
                implicitWidth:  codeLabel.implicitWidth + Kirigami.Units.gridUnit * 2
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
                    font.letterSpacing: 2
                }
            }

            QQC2.Button {
                text: i18n("Copy code")
                icon.name: "edit-copy"
                enabled: deviceFlow.userCode !== ""
                onClicked: {
                    if (deviceFlow.userCode === "")
                        return
                    clipboardProxy.text = deviceFlow.userCode
                    clipboardProxy.selectAll()
                    clipboardProxy.copy()
                }
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
                text: i18n("Waiting for authorization...")
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
