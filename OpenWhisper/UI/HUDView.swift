import SwiftUI

struct HUDView: View {
    static let cornerRadius: CGFloat = 18
    static let horizontalPadding: CGFloat = 18
    static let verticalPadding: CGFloat = 12

    var model: HUDModel

    var body: some View {
        HStack(spacing: 12) {
            icon
            content
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .frame(width: HUDPanel.size.width, height: HUDPanel.size.height)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var icon: some View {
        switch model.phase {
        case .recording:
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating)
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .message(_, let kind):
            Image(systemName: symbolName(for: kind))
                .font(.title2)
                .foregroundStyle(color(for: kind))
        case .hidden:
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .recording:
            VStack(alignment: .leading, spacing: 4) {
                LevelBarsView(levels: model.levels)
                    .frame(height: 22)
                Text(model.detail.isEmpty ? "Listening. \(model.hotKeyDescription) to stop, ⎋ to cancel" : "Listening · \(model.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        case .transcribing:
            VStack(alignment: .leading, spacing: 2) {
                Text("Transcribing…")
                    .font(.body.weight(.medium))
                if !model.detail.isEmpty {
                    Text(model.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        case .message(let text, _):
            Text(text)
                .font(.body.weight(.medium))
                .lineLimit(2)
        case .hidden:
            EmptyView()
        }
    }

    private func symbolName(for kind: HUDModel.MessageKind) -> String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func color(for kind: HUDModel.MessageKind) -> Color {
        switch kind {
        case .success: return .green
        case .warning: return .yellow
        case .info: return .white
        }
    }
}

struct LevelBarsView: View {
    static let barWidth: CGFloat = 3
    static let barSpacing: CGFloat = 2
    static let minimumBarHeight: CGFloat = 3

    let levels: [Float]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: Self.barSpacing) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(
                            width: Self.barWidth,
                            height: max(Self.minimumBarHeight, CGFloat(levels[index]) * proxy.size.height)
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .animation(.linear(duration: 0.08), value: levels)
        }
    }
}
