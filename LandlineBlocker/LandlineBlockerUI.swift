import SwiftUI

struct LBScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: 72)
                .allowsHitTesting(false)
        }
    }
}

struct LBPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SectionTitle: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }
}

struct MetricTile: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text("\(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatLine: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.footnote)
    }
}

struct RecognitionRow: View {
    let parsed: ParsedNumber

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: parsed.isValid ? "checkmark.circle.fill" : "minus.circle.fill")
                .foregroundStyle(parsed.isValid ? Color.green : Color.orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(parsed.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        if parsed.isValid {
            return PhoneNumberPresentation.masked(parsed.normalized)
        }
        if parsed.kind == .mobile {
            return "手机号已跳过"
        }
        return "未识别号码"
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .center, spacing: 7) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            ProgressView("处理中...")
                .padding(20)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

extension CallDirectoryExtensionStatus {
    var iconName: String {
        switch self {
        case .enabled:
            return "checkmark.shield.fill"
        case .disabled:
            return "shield.slash"
        case .unknown:
            return "questionmark.circle"
        case .unavailable:
            return "exclamationmark.triangle.fill"
        }
    }
}

extension String {
    var isFailureMessage: Bool {
        contains("失败") || contains("错误")
    }
}
