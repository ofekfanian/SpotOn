import SwiftUI

struct SnapLearnView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var wordBankVM: WordBankViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var image: UIImage?
    @State private var result: VisionService.Result?
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var added = false
    @State private var showCamera = false
    @State private var showLibrary = false

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        NavigationStack {
            ZStack {
                (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                ScatteredLettersBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        header
                        imageArea
                        if isLoading {
                            VStack(spacing: 10) { ProgressView(); Text("Identifying...").font(.caption).foregroundColor(.secondary) }
                                .padding(.vertical, 12)
                        } else if let result { resultCard(result) }
                        else if let errorMsg { Text(errorMsg).font(.subheadline).foregroundColor(.red).multilineTextAlignment(.center) }

                        VStack(spacing: 12) {
                            if cameraAvailable {
                                captureButton(title: "Take a Photo", icon: "camera.fill", gradient: LinearGradient.crystal) { showCamera = true }
                            }
                            captureButton(title: "Choose from Library", icon: "photo.on.rectangle", gradient: LinearGradient.crystalShort) { showLibrary = true }
                        }
                        .padding(.horizontal)
                        Spacer(minLength: 20)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Snap & Learn").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .fullScreenCover(isPresented: $showCamera) { ImagePicker(sourceType: .camera) { handleNewImage($0) }.ignoresSafeArea() }
            .sheet(isPresented: $showLibrary) { ImagePicker(sourceType: .photoLibrary) { handleNewImage($0) }.ignoresSafeArea() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "viewfinder").font(.system(size: 40)).foregroundStyle(LinearGradient.crystal)
            Text("Point at anything and learn its name in English and Hebrew.")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private var imageArea: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else {
                RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial)
                Image(systemName: "photo").font(.system(size: 44)).foregroundColor(.secondary)
            }
        }
        .frame(height: 240).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(LinearGradient.crystal.opacity(0.4), lineWidth: 1.5))
        .padding(.horizontal)
    }

    private func resultCard(_ result: VisionService.Result) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Text(result.english.capitalized).font(.title.bold()).foregroundStyle(LinearGradient.crystal)
                SpeakButton(text: result.english)
            }
            Text(result.hebrew).font(.title2.bold()).foregroundColor(.crystalMint).environment(\.layoutDirection, .rightToLeft)
            if !result.description.isEmpty {
                Text(result.description).font(.footnote).italic().foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            Button { Task { await addToWordBank(result) } } label: {
                Label(added ? "Added to Word Bank" : "Add to Word Bank", systemImage: added ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 50)
                    .background(added ? AnyShapeStyle(Color.crystalMint) : AnyShapeStyle(LinearGradient.crystal)).cornerRadius(14)
            }
            .disabled(added)
        }
        .padding(20).background(.ultraThinMaterial).cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(LinearGradient.crystal.opacity(0.35), lineWidth: 1))
        .padding(.horizontal).transition(.scale.combined(with: .opacity))
    }

    private func captureButton(title: String, icon: String, gradient: LinearGradient, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.headline).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 52).background(gradient).cornerRadius(16)
                .shadow(color: Color.crystalBlue.opacity(0.25), radius: 8, y: 4)
        }
    }

    private func handleNewImage(_ newImage: UIImage) {
        image = newImage; result = nil; errorMsg = nil; added = false; isLoading = true
        Task {
            let identified = await VisionService.shared.identify(image: newImage)
            await MainActor.run {
                isLoading = false
                if let identified { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { result = identified } }
                else { errorMsg = "Couldn't identify that. Try another photo or check your connection." }
            }
        }
    }

    private func addToWordBank(_ result: VisionService.Result) async {
        guard let uid = authVM.user?.uid else { return }
        let level = authVM.userProfile?.level ?? "intermediate"
        let word = Word(word: result.english.capitalized, translation: result.hebrew,
                        definition: result.description, context: "Identified with the camera", level: level)
        await wordBankVM.addWord(word, uid: uid)
        try? await RealtimeDatabaseService.shared.addXP(10, for: uid)
        withAnimation { added = true }
    }
}

#Preview("Light") {
    SnapLearnView().environmentObject(AuthViewModel()).environmentObject(WordBankViewModel())
        .preferredColorScheme(.light)
}
#Preview("Dark") {
    SnapLearnView().environmentObject(AuthViewModel()).environmentObject(WordBankViewModel())
        .preferredColorScheme(.dark)
}
