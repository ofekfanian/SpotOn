import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = LeaderboardViewModel()
    @State private var showAddFriend = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Your Invite Code").font(.caption).foregroundColor(.secondary)
                        Text(authVM.userProfile?.inviteCode ?? "------")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(LinearGradient.crystal)
                        HStack(spacing: 12) {
                            Button { showAddFriend = true } label: {
                                Label("Add Friend", systemImage: "person.badge.plus")
                                    .font(.subheadline.bold()).frame(maxWidth: .infinity).frame(height: 44)
                                    .background(LinearGradient.crystalShort).foregroundColor(.white).cornerRadius(12)
                            }
                            Button { showShare = true } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline.bold()).frame(maxWidth: .infinity).frame(height: 44)
                                    .background(.ultraThinMaterial).foregroundColor(.primary).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.crystalBlue.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                    .padding(18).background(.ultraThinMaterial).cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient.crystal.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal)

                    if vm.isLoading {
                        ProgressView().padding(.top, 40)
                    } else if vm.stats.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2").font(.system(size: 44)).foregroundStyle(LinearGradient.crystalShort)
                            Text("No friends yet").font(.headline)
                            Text("Add friends to see the leaderboard").font(.subheadline)
                                .foregroundColor(.secondary).multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(vm.stats.enumerated()), id: \.element.uid) { index, stat in
                                LeaderboardRow(rank: index + 1, stat: stat, isMe: stat.uid == authVM.user?.uid).padding(.horizontal)
                            }
                        }
                    }
                    Spacer(minLength: 32)
                }
                .padding(.top)
            }
            .navigationTitle("Leaderboard").navigationBarTitleDisplayMode(.large)
            .task {
                if let profile = authVM.userProfile, let uid = authVM.user?.uid {
                    await vm.load(friendUIDs: profile.friendUIDs, myUID: uid)
                }
            }
            .sheet(isPresented: $showAddFriend) { AddFriendSheet(vm: vm).environmentObject(authVM) }
            .sheet(isPresented: $showShare) {
                if let code = authVM.userProfile?.inviteCode {
                    ShareSheet(text: "Join me on SpotOn! Use my invite code: \(code)")
                }
            }
        }
    }
}

private struct LeaderboardRow: View {
    let rank: Int; let stat: FriendStats; let isMe: Bool
    private var medalColor: Color {
        switch rank { case 1: return .crystalGold; case 2: return Color(hex: "C0C0C0"); case 3: return Color(hex: "CD7F32"); default: return .secondary }
    }
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if rank <= 3 { Image(systemName: "medal.fill").font(.title2).foregroundColor(medalColor) }
                else { Text("\(rank)").font(.headline).foregroundColor(.secondary) }
            }
            .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(stat.username).font(.headline)
                    if isMe { Text("(You)").font(.caption).foregroundColor(.crystalBlue) }
                }
                HStack(spacing: 10) {
                    Label("\(stat.streak)d", systemImage: "flame.fill").foregroundColor(.orange)
                    Label("\(stat.wordCount)", systemImage: "book.fill").foregroundColor(.crystalBlue)
                }
                .font(.caption)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stat.xp)").font(.title3.bold()).foregroundStyle(LinearGradient.crystal)
                Text("XP").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(isMe ? Color.crystalBlue.opacity(0.08) : Color(.systemBackground).opacity(0.01))
        .background(.ultraThinMaterial).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isMe ? Color.crystalBlue.opacity(0.4) : Color.crystalBlue.opacity(0.1), lineWidth: 1))
    }
}

struct AddFriendSheet: View {
    @ObservedObject var vm: LeaderboardViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "person.badge.plus").font(.system(size: 56)).foregroundStyle(LinearGradient.crystalShort)
                Text("Enter Invite Code").font(.title2.bold())
                Text("Ask your friend for their 6-character code").font(.subheadline).foregroundColor(.secondary)
                TextField("ABCDEF", text: $code)
                    .textCase(.uppercase).multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold, design: .monospaced)).padding()
                    .background(.ultraThinMaterial).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.crystalBlue.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 40)
                if let err = errorMsg { Text(err).foregroundColor(.red).font(.caption) }
                if success { Label("Friend added!", systemImage: "checkmark.circle.fill").foregroundColor(.crystalMint).font(.headline) }
                Button { Task { await addFriend() } } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(LinearGradient.crystal)
                        if isLoading { ProgressView().tint(.white) } else { Text("Add").font(.headline).foregroundColor(.white) }
                    }
                    .frame(height: 52)
                }
                .padding(.horizontal, 40).disabled(code.count < 4 || isLoading).opacity(code.count < 4 ? 0.5 : 1)
                Spacer()
            }
            .navigationTitle("Add Friend").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func addFriend() async {
        guard let uid = authVM.user?.uid else { return }
        isLoading = true; errorMsg = nil
        do {
            try await FriendsService.shared.addFriend(inviteCode: code, for: uid)
            success = true
            if let profile = authVM.userProfile { await vm.load(friendUIDs: profile.friendUIDs, myUID: uid) }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
