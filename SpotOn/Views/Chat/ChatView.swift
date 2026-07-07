import SwiftUI

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @Environment(\.colorScheme) private var scheme
    @State private var inputText = ""
    @State private var showCall = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                (scheme == .dark ? Color.darkBg : Color.lightBg).ignoresSafeArea()
                ScatteredLettersBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.messages.filter { $0.role != "system" }) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                                    .onTapGesture { if msg.role == "assistant" { vm.speak(msg) } }
                            }
                            if vm.isLoading { TypingIndicator().id("typing") }
                        }
                        .padding(.horizontal).padding(.vertical, 12)
                    }
                    .onChange(of: vm.messages.count) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let lastID = vm.messages.last?.id { proxy.scrollTo(lastID, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.isLoading) {
                        if vm.isLoading { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                    }
                }

                if let err = vm.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text(err).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button { Task { await vm.retry() } } label: {
                            Label("Retry", systemImage: "arrow.clockwise").font(.caption.bold())
                                .foregroundStyle(LinearGradient.crystalShort)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Divider().opacity(0.3)

                HStack(spacing: 10) {
                    TextField("Type in English...", text: $inputText, axis: .vertical)
                        .lineLimit(1...4).padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.ultraThinMaterial).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.crystalBlue.opacity(0.3), lineWidth: 1))
                        .focused($inputFocused)
                    Button {
                        let text = inputText; inputText = ""
                        Task { await vm.sendMessage(text: text) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 36))
                            .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(LinearGradient.crystalShort))
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
                }
                .padding(.horizontal, 12).padding(.vertical, 10).background(.ultraThinMaterial)
            }
            .navigationTitle("English Tutor").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill.checkmark").foregroundStyle(LinearGradient.crystalShort)
                        CrystalText(text: "English Tutor", font: .headline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCall = true } label: { Image(systemName: "phone.fill").foregroundStyle(LinearGradient.crystalShort) }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { withAnimation { vm.clearConversation() } } label: { Image(systemName: "trash").foregroundColor(.secondary) }
                }
            }
            .fullScreenCover(isPresented: $showCall) { VoiceCallView() }
            .applyTabBarVisibility()
            }
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) }
            if !isUser {
                Circle().fill(LinearGradient.crystalShort).frame(width: 28, height: 28)
                    .overlay(Image(systemName: "person.fill.checkmark").font(.caption2).foregroundColor(.white))
            }
            Text(message.content).font(.subheadline).foregroundColor(isUser ? .white : .primary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(isUser ? AnyView(LinearGradient.crystalShort) : AnyView(Color(.systemBackground).opacity(0.01)))
                .background(isUser ? Color.clear : Color(.systemGray6))
                .cornerRadius(18, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                .shadow(color: isUser ? Color.crystalBlue.opacity(0.2) : Color.black.opacity(0.04), radius: 4, y: 2)
            if !isUser {
                Image(systemName: "speaker.wave.2.fill").font(.caption2).foregroundColor(.crystalBlue.opacity(0.6))
            }
            if isUser {
                Circle().fill(LinearGradient.crystalShort).frame(width: 28, height: 28)
                    .overlay(Image(systemName: "person.fill").font(.caption2).foregroundColor(.white))
            }
            if !isUser { Spacer(minLength: 50) }
        }
    }
}

private struct TypingIndicator: View {
    @State private var phase = 0
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle().fill(LinearGradient.crystalShort).frame(width: 28, height: 28)
                .overlay(Image(systemName: "person.fill.checkmark").font(.caption2).foregroundColor(.white))
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle().fill(Color.secondary.opacity(0.6)).frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.4 : 1.0)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12).background(Color(.systemGray6))
            .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
            Spacer(minLength: 50)
        }
        .onAppear { phase = 2 }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

#Preview("Light") { ChatView().preferredColorScheme(.light) }
#Preview("Dark")  { ChatView().preferredColorScheme(.dark) }
