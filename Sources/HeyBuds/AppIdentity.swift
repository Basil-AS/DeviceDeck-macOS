import Foundation

/// The legacy identity is retained only to migrate local settings and prevent
/// two generations of the app from owning the same earbud control session.
enum AppIdentity {
    static let name="DeviceDeck"
    static let version="0.7.0-alpha.13"
    static let projectURL=URL(string:"https://github.com/Basil-AS/DeviceDeck-macOS")!
    static let releasesURL=projectURL.appendingPathComponent("releases/latest")
    static let bundleID="app.devicedeck.macos"
    static let legacyBundleIDs=["local.heybuds.app","local.encobar.app"]
    static let migrationKey="devicedeckPreferencesMigratedV1"

    static func migratedPreferences(current:[String:Any],legacy:[String:Any]) -> [String:Any] {
        guard current[migrationKey] as? Bool != true else { return current }
        var result=current
        let boolKeys:Set<String>=["backgroundMode","connectionTips","menuBattery","autoReconnect","notifyLow"]
        let stringKeys:Set<String>=["language","appearance","selectedDevice"]
        for (key,value) in legacy where result[key] == nil {
            if boolKeys.contains(key),value is Bool { result[key]=value }
            else if (stringKeys.contains(key) || key.hasPrefix("model.")),value is String { result[key]=value }
            else if key == "lowThreshold",let threshold=value as? Int,(1...100).contains(threshold) { result[key]=threshold }
        }
        result[migrationKey]=true
        return result
    }
    static func migrateLegacyPreferences(defaults:UserDefaults = .standard) {
        let current=defaults.persistentDomain(forName:bundleID) ?? [:]
        guard current[migrationKey] as? Bool != true else { return }
        let legacy=legacyBundleIDs.reduce(into:[String:Any]()) { result,id in
            for (key,value) in defaults.persistentDomain(forName:id) ?? [:] where result[key] == nil { result[key]=value }
        }
        defaults.setPersistentDomain(migratedPreferences(current:current,legacy:legacy),forName:bundleID)
    }
}
