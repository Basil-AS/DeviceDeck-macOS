import AppKit
import Observation

/// Updates are published on the DeviceDeck GitHub Releases page.
@MainActor @Observable final class NativeUpdater {
    private(set) var canCheckForUpdates=true
    @ObservationIgnored var onWillPresentUI:(() -> Void)?

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        onWillPresentUI?()
        NSWorkspace.shared.open(AppIdentity.releasesURL)
    }
}
