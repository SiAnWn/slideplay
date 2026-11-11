import SwiftUI

/// 首次进入 / 未选择文件夹时的引导页。
struct WelcomeView: View {
    let onPick: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "play.rectangle.stack.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.8))
            Text("SlidePlay")
                .font(.title2.bold())
            Text("选择一个包含视频的文件夹\n上下滑动全屏播放，完全本地、不联网")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            Button(action: onPick) {
                Text("选择视频文件夹")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Theme.gradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 10)
            Text("支持 MP4 / MOV / M4V")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
        .foregroundStyle(.white)
    }
}
