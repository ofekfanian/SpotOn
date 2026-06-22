import SwiftUI

struct VoiceCallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = VoiceCallViewModel()
    @State private var permissionDenied = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.darkBg, Color.crystalBlue.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScatteredLettersBackground().ignoresSafeArea().opacity(0.4)

            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                VStack(spacing: 8) {
                    Text("English Tutor").font(.title2.bold()).foregroundColor(.white)
                    Text(statusText).font(.subheadline).foregroundColor(.white.opacity(0.7)).contentTransition(.opacity)
                    Button { vm.handsFree.toggle() } label: {
                        Label(vm.handsFree ? "Hands-free on" : "Hands-free off",
                              systemImage: vm.handsFree ? "infinity.circle.fill" : "hand.tap.fill")
                            .font(.caption.bold()).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.ultraThinMaterial).clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }

                ZStack {
                    Circle().fill(LinearGradient.crystal).frame(width: 150, height: 150)
                        .scaleEffect(pulse ? 1.08 : 1).shadow(color: Color.crystalBlue.opacity(0.6), radius: 30)
                    Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2).frame(width: 170, height: 170)
                        .scaleEffect(pulse ? 1.15 : 1).opacity(pulse ? 0 : 0.6)
                    Image(systemName: "person.wave.2.fill").font(.system(size: 56)).foregroundColor(.white)
                }
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                .onChange(of: vm.phase) { _, _ in updatePulse() }

                VStack(spacing: 14) {
                    if !vm.lastUserText.isEmpty || vm.phase == .listening {
                        transcriptBubble(label: "You",
                            text: vm.phase == .listening ? (vm.liveTranscript.isEmpty ? "Listening..." : vm.liveTranscript) : vm.lastUserText,
                            color: .crystalMint)
                    }
                    if !vm.lastTutorText.isEmpty && vm.phase != .listening {
                        transcriptBubble(label: "Tutor", text: vm.lastTutorText, color: .white)
                    }
                    if let err = vm.errorMessage { Text(err).font(.caption).foregroundColor(.red) }
                }
                .frame(maxWidth: .infinity).padding(.horizontal)

                Spacer()

                HStack(spacing: 50) {
                    Button { Task { await vm.micTapped() } } label: {
                        Image(systemName: micIcon).font(.system(size: 30, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 78, height: 78).background(micColor).clipShape(Circle())
                            .shadow(color: micColor.opacity(0.5), radius: 12)
                    }
                    .disabled(vm.phase == .thinking).opacity(vm.phase == .thinking ? 0.5 : 1)

                    Button { vm.endCall(); dismiss() } label: {
                        Image(systemName: "phone.down.fill").font(.system(size: 28, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 78, height: 78).background(Color.red).clipShape(Circle())
                            .shadow(color: Color.red.opacity(0.5), radius: 12)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
        .task {
            let ok = await vm.beginCall()
            permissionDenied = !ok
        }
        .alert("Permission needed", isPresented: $permissionDenied) {
            Button("OK") { dismiss() }
        } message: { Text("Enable Microphone and Speech Recognition in Settings to use voice calls.") }
    }

    private func updatePulse() { pulse = (vm.phase == .listening || vm.phase == .speaking) }

    private var statusText: String {
        switch vm.phase {
        case .idle: return vm.lastTutorText.isEmpty ? "Tap the mic to start talking" : "Tap the mic to reply"
        case .listening: return "Listening..."
        case .thinking: return "Thinking..."
        case .speaking: return "Speaking..."
        }
    }
    private var micIcon: String {
        switch vm.phase {
        case .listening: return "stop.fill"
        case .thinking: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        default: return "mic.fill"
        }
    }
    private var micColor: Color { vm.phase == .listening ? .crystalMint : .crystalBlue }

    private func transcriptBubble(label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2.bold()).foregroundColor(color.opacity(0.8))
            Text(text).font(.body).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14).background(.ultraThinMaterial).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.3), lineWidth: 1))
    }
}
