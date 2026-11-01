import SwiftUI
import StreetPiCore

extension EnvironmentValues {
    @Entry var dnsActionNotice: ActionNotice? = nil
}

struct DeskScroll<Content: View>: View {
    var wide: Bool
    @ViewBuilder var content: () -> Content
    @Environment(\.dnsActionNotice) private var actionNotice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Rhythm.block) {
                if let actionNotice {
                    ActionNoticeBanner(notice: actionNotice, theme: .house)
                }
                content()
            }
            .padding(.horizontal, Rhythm.page)
            .padding(.vertical, Rhythm.block)
            .frame(maxWidth: wide ? 720 : 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }
}

struct DeskLink: View {
    var title: String
    var blurb: String
    var symbol: String
    var theme: StreetTheme
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Rhythm.line) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(blurb)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.footnote)
                    .foregroundStyle(theme.tertiary)
                    .accessibilityHidden(true)
                    .padding(.top, 4)
            }
            .padding(Rhythm.line)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(blurb)")
    }
}

struct DeskCard<Content: View>: View {
    var theme: StreetTheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            content()
        }
        .padding(Rhythm.line)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        }
    }
}

struct EmptyNote: View {
    var title: String
    var detail: String
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text(title)
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Rhythm.line)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        }
    }
}

struct WideBack: View {
    var title: String
    var theme: StreetTheme
    var action: () -> Void

    var body: some View {
        Button(title, systemImage: "chevron.backward", action: action)
            .font(.body)
            .foregroundStyle(theme.accent)
            .labelStyle(.titleAndIcon)
            .frame(minHeight: 44, alignment: .leading)
    }
}
