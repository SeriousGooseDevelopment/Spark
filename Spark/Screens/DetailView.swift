import SwiftUI

/// The generic pushed screen: a list of rows, or a long-form article body.
/// Rows are one of three shapes — toggle, read-only value, or an action that
/// pushes another screen, opens a form, or asks for confirmation.
struct DetailView: View {
    @Environment(Store.self) private var store
    var spec: DetailSpec

    var body: some View {
        PushedScreen(title: spec.title, subtitle: spec.subtitle, onBack: store.back) {
            if let body = spec.body {
                articleBody(body)
            } else {
                GroupCard(cornerRadius: 18, soft: true) {
                    SeparatedRows(items: spec.rows, separator: SK.separatorSoft) { row in
                        detailRow(row)
                    }
                }
            }

            Text(spec.note)
                .font(SKFont.regular(11.5))
                .lineSpacing(11.5 * 0.5)
                .foregroundStyle(SK.ink5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .padding(.top, 12)
        }
    }

    private func articleBody(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(body.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, para in
                Text(para)
                    .font(SKFont.regular(14.5))
                    .lineSpacing(6)
                    .foregroundStyle(SK.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .softShadow()
    }

    private func detailRow(_ row: DetailRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.label)
                    .font(SKFont.medium(14.5))
                    .tracking(-0.2)
                    .foregroundStyle(row.isDanger ? SK.danger : SK.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(SKFont.regular(12))
                        .lineSpacing(12 * 0.45)
                        .foregroundStyle(SK.ink4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)

            if let key = row.toggleKey {
                SparkToggle(isOn: store.isOn(key), compact: true) { store.toggle(key) }
            }
            if let value = row.value, !value.isEmpty {
                Text(value)
                    .font(SKFont.regular(13))
                    .foregroundStyle(SK.ink4)
            }
            if row.isTappable {
                Chevron(size: 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { activate(row) }
    }

    private func activate(_ row: DetailRow) {
        if let key = row.toggleKey {
            store.toggle(key)
            return
        }
        switch row.action {
        case .none: break
        case .push(let spec): store.show(spec)
        case .form(let spec): store.openForm(spec)
        case .confirm(let spec): store.ask(spec)
        case .tab(let tab): store.go(tab)
        }
    }
}
