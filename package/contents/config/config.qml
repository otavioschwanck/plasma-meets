import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Geral")
        icon: "configure"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Aparência")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
}
