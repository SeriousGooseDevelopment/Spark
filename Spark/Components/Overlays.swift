import SwiftUI

// MARK: - Scaffolding

/// Dimmed backdrop shared by the sheets and the confirm dialog. The design
/// pairs the tint with a 2px backdrop blur, which is imperceptible at this
/// scale — a material here would wash the screen out instead.
struct Scrim: View {
    var opacity: Double = 0.40
    var onTap: () -> Void

    var body: some View {
        Color(hex: 0x0E142C, opacity: opacity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .transition(.opacity)
    }
}

/// A bottom sheet with the grabber, title and 30pt top corners.
struct BottomSheet<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: () -> Content

    @Environment(\.safeBottom) private var safeBottom

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(SK.grabber)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 14)

            Text(title)
                .font(SKFont.bold(17))
                .tracking(-0.4)
                .foregroundStyle(SK.ink)
                .padding(.horizontal, 4)

            if let subtitle {
                Text(subtitle)
                    .font(SKFont.regular(12.5))
                    .foregroundStyle(SK.ink3)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
                .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26 + safeBottom * 0.4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SK.card)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
        .shadow(color: Color(hex: 0x0E142C, opacity: 0.24), radius: 25, x: 0, y: -20)
        // Deliberately its natural height — the parent ZStack anchors it to the
        // bottom. Claiming full height here made the panel stretch and drift up
        // when the keyboard shrank the available space.
        .transition(.move(edge: .bottom))
    }
}

/// The full-width button at the foot of each sheet.
struct SheetButton: View {
    var title: String
    var background: Color
    var foreground: Color
    var height: CGFloat = 52
    var action: () -> Void

    var body: some View {
        Text(title)
            .font(SKFont.semibold(14.5))
            .tracking(-0.2)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture(perform: action)
    }
}

// MARK: - Quick actions

struct QuickAction: Identifiable {
    let id = UUID()
    var label: String
    var subtitle: String
    var icon: String
    var action: () -> Void
}

struct QuickActionsSheet: View {
    var actions: [QuickAction]
    var onCancel: () -> Void

    var body: some View {
        BottomSheet(title: "Quick actions") {
            VStack(spacing: 10) {
                ForEach(actions) { action in
                    HStack(spacing: 14) {
                        IconTile(side: 40, corner: 13, background: SK.card, shadowed: true) {
                            StrokeIcon(path: action.icon, size: 20)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.label)
                                .font(SKFont.bold(14.5))
                                .tracking(-0.25)
                                .foregroundStyle(SK.ink)
                            Text(action.subtitle)
                                .font(SKFont.regular(12))
                                .foregroundStyle(SK.ink3)
                        }
                        Spacer(minLength: 8)
                        Chevron(size: 13, color: SK.chevronStrong, lineWidth: 1.9)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(SK.sheetRow, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture(perform: action.action)
                }

                SheetButton(title: "Cancel", background: SK.ink, foreground: .white, action: onCancel)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Value picker

struct PickerSheet: View {
    var spec: PickerSpec
    var selected: String
    var onPick: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        BottomSheet(title: spec.title) {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ForEach(Array(spec.options.enumerated()), id: \.element) { index, option in
                        let isSelected = option == selected
                        HStack(spacing: 12) {
                            Text(option)
                                .font(isSelected ? SKFont.bold(14.5) : SKFont.medium(14.5))
                                .tracking(-0.2)
                                .foregroundStyle(isSelected ? SK.accent : SK.ink)
                            Spacer(minLength: 8)
                            if isSelected {
                                GlyphIcon.check()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                        .onTapGesture { onPick(option) }

                        if index < spec.options.count - 1 {
                            RowSeparator(color: SK.pickerSeparator)
                        }
                    }
                }
                .background(SK.sheetRow)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                SheetButton(title: "Cancel", background: SK.separator, foreground: SK.ink, action: onCancel)
            }
        }
    }
}

// MARK: - Form

/// The sheet behind every "add" and "edit" action: labelled fields, a primary
/// button that stays disabled until the required ones are filled, and Cancel.
struct FormSheet: View {
    @Environment(Store.self) private var store
    var spec: FormSpec

    @FocusState private var focused: String?

    var body: some View {
        BottomSheet(title: spec.title, subtitle: spec.subtitle) {
            VStack(spacing: 14) {
                VStack(spacing: 12) {
                    ForEach(spec.fields) { field in
                        fieldView(field)
                    }
                }

                Text(spec.primary)
                    .font(SKFont.bold(14.5))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(store.formIsValid ? SK.accent : SK.accent.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture { store.submitForm() }
                    .allowsHitTesting(store.formIsValid)
                    .accessibilityAddTraits(.isButton)

                SheetButton(title: "Cancel", background: SK.separator, foreground: SK.ink) {
                    store.closeForm()
                }
            }
            .onAppear { focused = spec.fields.first { $0.kind != .choice }?.id }
        }
    }

    @ViewBuilder
    private func fieldView(_ field: FormField) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(field.label)
                .font(SKFont.semibold(12))
                .foregroundStyle(SK.ink3)
                .padding(.leading, 4)

            switch field.kind {
            case .choice:
                choiceRow(field)
            case .multiline:
                textInput(field, axis: .vertical)
                    .frame(minHeight: 76, alignment: .top)
            default:
                textInput(field, axis: .horizontal)
            }
        }
    }

    private func textInput(_ field: FormField, axis: Axis) -> some View {
        let binding = Binding(
            get: { store.formValue(field.id) },
            set: { store.setFormValue(field.id, $0) }
        )
        return Group {
            if field.kind == .password {
                SecureField(field.placeholder, text: binding)
            } else {
                TextField(field.placeholder, text: binding, axis: axis)
            }
        }
        .font(SKFont.medium(15))
        .foregroundStyle(SK.ink)
        .tint(SK.accent)
        .focused($focused, equals: field.id)
        .textInputAutocapitalization(autocapitalization(field))
        .autocorrectionDisabled(field.kind == .domain || field.kind == .email)
        .keyboardType(keyboard(field))
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SK.sheetRow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel(field.label)
    }

    private func choiceRow(_ field: FormField) -> some View {
        HStack(spacing: 7) {
            ForEach(field.options, id: \.self) { option in
                let selected = store.formValue(field.id) == option
                Text(option)
                    .font(SKFont.semibold(12.5))
                    .foregroundStyle(selected ? .white : SK.ink2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(selected ? SK.accent : SK.sheetRow,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture { store.setFormValue(field.id, option) }
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func autocapitalization(_ field: FormField) -> TextInputAutocapitalization {
        switch field.kind {
        case .domain, .email, .password: return .never
        case .multiline: return .sentences
        default: return .words
        }
    }

    private func keyboard(_ field: FormField) -> UIKeyboardType {
        switch field.kind {
        case .domain: return .URL
        case .email: return .emailAddress
        default: return .default
        }
    }
}

// MARK: - Confirm

struct ConfirmDialog: View {
    var spec: ConfirmSpec
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(spec.title)
                .font(SKFont.bold(17))
                .tracking(-0.4)
                .foregroundStyle(SK.ink)
                .multilineTextAlignment(.center)

            Text(spec.body)
                .font(SKFont.regular(13))
                .lineSpacing(4)
                .foregroundStyle(SK.ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Text(spec.actionLabel)
                .font(SKFont.bold(14.5))
                .tracking(-0.2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(SK.danger, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture(perform: onConfirm)
                .padding(.top, 20)

            Text("Cancel")
                .font(SKFont.semibold(14.5))
                .tracking(-0.2)
                .foregroundStyle(SK.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
                .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(SK.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(hex: 0x0E142C, opacity: 0.30), radius: 30, x: 0, y: 30)
        .padding(.horizontal, 34)
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }
}

// MARK: - Toast

struct Toast: View {
    var text: String
    var style: ToastStyle = .success

    var body: some View {
        HStack(spacing: 9) {
            if style == .error {
                GlyphIcon.close(size: 12, color: .white)
            } else {
                GlyphIcon.check(width: 14, color: SK.toastCheck)
            }
            Text(text)
                .font(SKFont.semibold(13))
                .tracking(-0.2)
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 300)
        .background(style == .error ? SK.danger : SK.ink, in: Capsule())
        .shadow(color: Color(hex: 0x0E142C, opacity: 0.28), radius: 14, x: 0, y: 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - App picker (search the full recognized-app catalog for one device)

/// Search over AdGuard's full catalog (~100 entries on a real box) rather
/// than listing everything inline — the catalog is too long to browse as a
/// flat toggle list. Stays open across multiple taps (a "Done" button
/// dismisses) since blocking several apps in one sitting is the common case.
struct AppPickerSheet: View {
    @Environment(Store.self) private var store
    var deviceID: String
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [ServiceCatalogEntry] {
        let all = store.serviceCatalog.sorted { $0.name < $1.name }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        BottomSheet(title: "Block an app", subtitle: "Search for any app or service to block on this device.") {
            VStack(spacing: 14) {
                TextField("Search apps", text: $query)
                    .font(SKFont.medium(15))
                    .foregroundStyle(SK.ink)
                    .tint(SK.accent)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(SK.sheetRow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Search apps")

                if store.serviceCatalog.isEmpty {
                    ProgressView()
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity)
                } else if filtered.isEmpty {
                    Text("No matching apps")
                        .font(SKFont.regular(13))
                        .foregroundStyle(SK.ink4)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, app in
                                appRow(app)
                                if index < filtered.count - 1 {
                                    RowSeparator(color: SK.pickerSeparator)
                                }
                            }
                        }
                        .background(SK.sheetRow)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .frame(maxHeight: 320)
                }

                SheetButton(title: "Done", background: SK.accent, foreground: .white) {
                    store.closeAppPicker()
                }
            }
        }
    }

    private func appRow(_ app: ServiceCatalogEntry) -> some View {
        let on = store.isAppBlocked(deviceID, app.id)
        return HStack(spacing: 12) {
            Text(app.name)
                .font(on ? SKFont.bold(14.5) : SKFont.medium(14.5))
                .tracking(-0.2)
                .foregroundStyle(on ? SK.accent : SK.ink)
            Spacer(minLength: 8)
            if on {
                GlyphIcon.check()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleBlockedApp(deviceID, app.id) }
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Device claim (real devices seen on the network, not yet added)

/// Live-populated, unlike `PickerSheet` — devices arrive from an async network
/// call, so this can't be expressed as a precomputed `DetailSpec`/`PickerSpec`.
struct DeviceClaimSheet: View {
    @Environment(Store.self) private var store
    var devices: [AgentDevice]

    var body: some View {
        BottomSheet(title: "Add a device", subtitle: "Pick a device seen on your network.") {
            VStack(spacing: 14) {
                if devices.isEmpty {
                    ProgressView()
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity)
                } else {
                    // A real home network can easily have 15-20+ devices — cap
                    // the list's height and let it scroll internally, rather
                    // than the whole sheet growing past the screen with the
                    // Cancel button pushed out of reach.
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name.isEmpty ? "Unknown device" : device.name)
                                            .font(SKFont.semibold(14.5))
                                            .tracking(-0.2)
                                            .foregroundStyle(SK.ink)
                                        Text(device.mac)
                                            .font(SKFont.regular(12))
                                            .foregroundStyle(SK.ink3)
                                    }
                                    Spacer(minLength: 8)
                                    Chevron(size: 12)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                                .onTapGesture { Task { await store.claimDevice(device) } }

                                if index < devices.count - 1 {
                                    RowSeparator(color: SK.pickerSeparator)
                                }
                            }
                        }
                        .background(SK.sheetRow)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .frame(maxHeight: 340)
                }

                SheetButton(title: "Cancel", background: SK.separator, foreground: SK.ink) {
                    store.closeDeviceClaim()
                }
            }
        }
    }
}
