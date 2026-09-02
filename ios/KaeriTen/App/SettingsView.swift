import SwiftUI

/// M8: 設定画面のNavigationPathルート用マーカー。
struct SettingsRoute: Hashable {}

/// M8: BGM・SEの音量を個別に調整できる設定画面（doc §M8）。
/// 変更は即座に `AudioEngine` に反映し、`Progress`（UserDefaults）にも保存する。
struct SettingsView: View {
    @State private var progress = Progress.load()

    var body: some View {
        VStack(spacing: 40) {
            volumeRow(title: "BGM音量", value: $progress.bgmVolume) { newValue in
                AudioEngine.shared.bgmVolume = Float(newValue)
            }
            volumeRow(title: "SE音量", value: $progress.seVolume) { newValue in
                AudioEngine.shared.seVolume = Float(newValue)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func volumeRow(title: String, value: Binding<Double>, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.cyan)
            Slider(value: value, in: 0...1) { editing in
                guard !editing else { return }
                progress.save()
            }
            .tint(.cyan)
            .onChange(of: value.wrappedValue) { _, newValue in
                onChange(newValue)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
