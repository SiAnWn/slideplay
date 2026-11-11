import SwiftUI

/// 首次进入 / 没有可播放视频时的引导页。
/// 主路径：把视频放进 App 自己的 Documents 文件夹（"文件"App 里可见），再刷新。
struct WelcomeView: View {
    let onRefresh: () -> Void
    let onPick: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.8))
            Text("SlidePlay")
                .font(.title2.bold())
            Text("把视频放进 App 的文件夹：\n打开系统「文件」App → 我的 iPhone → SlidePlay\n把视频拖进去，然后回来点刷新")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            Button(action: onRefresh) {
                Text("刷新视频列表")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Theme.gradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 10)
            Button("或：选择手机里的其他文件夹", action: onPick)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
            Text("支持 MP4 / MOV / M4V")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
        .foregroundStyle(.white)
    }
}
