import Foundation
import SwiftData
import SwiftUI

/// Shared observable state used by both AppDelegate and SwiftUI views.
@Observable
final class AppState {
    var isSyncing = false
    var selectedTagFilter: String? = nil
    var scrollToItemId: UUID? = nil
    var lastSyncDate: Date? = nil
    var showSettings = false
    var errorMessage: String? = nil
    /// Feed filter mode
    var feedFilter: FeedFilter = .all
    /// Selected item for detail view
    var selectedItem: ResearchItem? = nil

    enum FeedFilter: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case saved = "Saved"
    }
}
