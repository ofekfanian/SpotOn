import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var rtdb = RealtimeDatabaseService.shared
    @ObservedObject private var profileImage = ProfileImageStore.shared

    @AppStorage("dailyReminderOn") private var reminderOn = true
    @AppStorage("dailyReminderHour") private var notifHour = 20
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    @State private var photoItem: PhotosPickerItem?
    @State private var showSignOutAlert = false

    private var displayName: String {
        (authVM.user?.email ?? "").components(separatedBy: "@").first?.capitalized ?? "You"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $photoItem, matching: .images) { ProfileAvatar(image: profileImage.image) }
                            .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName).font(.headline)
                            Text(authVM.user?.email ?? "—").font(.caption).foregroundColor(.secondary)
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text("Change Photo").font(.caption.bold()).foregroundColor(.crystalBlue)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    if profileImage.image != nil {
                        Button(role: .destructive) { profileImage.remove() } label: { Label("Remove Photo", systemImage: "trash") }
                    }
                }

                Section("Progress") {
                    LabeledContent("Level", value: (authVM.userProfile?.level ?? "—").capitalized)
                    HStack { Label("Streak", systemImage: "flame.fill").foregroundColor(.orange); Spacer(); Text("\(rtdb.streak) days").foregroundColor(.secondary) }
                    HStack { Label("XP", systemImage: "star.fill").foregroundColor(.crystalGold); Spacer(); Text("\(rtdb.xp)").foregroundColor(.secondary) }
                }

                Section("Appearance") {
                    Picker(selection: $appearance) {
                        ForEach(AppAppearance.allCases) { mode in Label(mode.label, systemImage: mode.icon).tag(mode.rawValue) }
                    } label: { Label("Theme", systemImage: "paintbrush.fill").foregroundColor(.crystalBlue) }
                    .pickerStyle(.menu)
                }

                Section("Notifications") {
                    Toggle(isOn: $reminderOn) { Label("Daily Reminder", systemImage: "bell.fill").foregroundColor(.crystalBlue) }
                    if reminderOn { Stepper("Remind me at \(notifHour):00", value: $notifHour, in: 6...22) }
                }
                .onChange(of: reminderOn) { _, on in updateReminder(on: on) }
                .onChange(of: notifHour) { _, _ in updateReminder(on: reminderOn) }

                Section("About") {
                    NavigationLink { AboutView() } label: { Label("About SpotOn", systemImage: "info.circle") }
                    LabeledContent("Version", value: "1.0.0")
                    Link(destination: URL(string: "https://example.com/privacy")!) { Label("Privacy Policy", systemImage: "lock.shield") }
                }

                Section {
                    Button(role: .destructive) { showSignOutAlert = true } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                        profileImage.save(uiImage)
                    }
                }
            }
            .alert("Sign Out?", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) { authVM.signOut() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func updateReminder(on: Bool) {
        if on { NotificationService.scheduleDailyReminder(at: notifHour) } else { NotificationService.cancelDailyReminder() }
    }
}

private struct ProfileAvatar: View {
    let image: UIImage?
    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else {
                LinearGradient.crystal
                Image(systemName: "person.fill").font(.system(size: 28)).foregroundColor(.white)
            }
        }
        .frame(width: 64, height: 64).clipShape(Circle())
        .overlay(Circle().strokeBorder(LinearGradient.crystal, lineWidth: 2))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.circle.fill").font(.system(size: 20))
                .foregroundStyle(.white, Color.crystalBlue).background(Circle().fill(.white).padding(2))
        }
    }
}
