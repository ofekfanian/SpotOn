import Foundation

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var stats: [FriendStats] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(friendUIDs: [String], myUID: String) async {
        isLoading = true
        do { stats = try await FriendsService.shared.fetchLeaderboard(friendUIDs: friendUIDs, myUID: myUID) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
