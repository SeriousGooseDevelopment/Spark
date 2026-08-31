import SwiftUI

/// Assembles the whole app in one z-stack, matching the design's layering:
/// tab content → shelf → pill → tab bar → sheets → dialog → toast.
struct RootView: View {
    @State private var store = Store()
    /// Captured once. The reader's insets pick up the keyboard as bottom inset
    /// while it is open, and these feed layout that must not move with it.
    @State private var deviceInsets: EdgeInsets?

    var body: some View {
        GeometryReader { geo in
            content
                .environment(store)
                .environment(\.safeTop, (deviceInsets ?? geo.safeAreaInsets).top)
                .environment(\.safeBottom, (deviceInsets ?? geo.safeAreaInsets).bottom)
                // `.container` only: the design's offsets are absolute from the
                // top of the display, so the notch and home indicator insets go
                // — but the keyboard region stays, so SwiftUI still lifts the
                // form sheet off the keyboard for us.
                .ignoresSafeArea(.container, edges: .all)
                .onAppear {
                    if deviceInsets == nil { deviceInsets = geo.safeAreaInsets }
                }
        }
        .background(SK.canvas)
        .preferredColorScheme(.light)
    }

    private var content: some View {
        ZStack {
            tabContent

            // Pushed screens stop short of the tab bar, which stays on top.
            // Only the topmost route renders; the stack can nest several deep.
            if let route = store.route {
                pushedScreen(route)
                    .padding(.bottom, SK.tabBarHeight)
                    .id(route.id)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(30)
            }

            TabBarShelf()
                .zIndex(31)

            if store.tab == .home && store.stack.isEmpty && store.sparkConnected {
                ConnectedPill()
                    .padding(.bottom, SK.tabBarHeight + 25)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .zIndex(31.5)
                    .contentShape(Capsule())
                    .onTapGesture { store.show(managedBoxDetail) }
                    .accessibilityAddTraits(.isButton)
            }

            SparkTabBar(
                current: store.tab,
                sheetOpen: store.sheetOpen,
                onSelect: store.go,
                onFAB: { store.setSheet(!store.sheetOpen) }
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .zIndex(32)

            // Each overlay group stays mounted so `allowsHitTesting` can flip
            // the instant it is dismissed. Inside an `if`, the outgoing scrim
            // and sheet keep swallowing taps for the length of their exit
            // animation — enough to eat a tap on the button underneath.
            ZStack(alignment: .bottom) {
                if store.sheetOpen {
                    Scrim { store.setSheet(false) }
                    QuickActionsSheet(actions: quickActions) { store.setSheet(false) }
                }
            }
            .allowsHitTesting(store.sheetOpen)
            .zIndex(40)

            ZStack(alignment: .bottom) {
                if let picker = store.picker {
                    Scrim { store.closePicker() }
                    PickerSheet(
                        spec: picker,
                        selected: store.value(picker.valueKey),
                        onPick: store.pick,
                        onCancel: store.closePicker
                    )
                }
            }
            .allowsHitTesting(store.picker != nil)
            .zIndex(44)

            ZStack(alignment: .bottom) {
                if let claimList = store.deviceClaimPicker {
                    Scrim { store.closeDeviceClaim() }
                    DeviceClaimSheet(devices: claimList)
                }
            }
            .allowsHitTesting(store.deviceClaimPicker != nil)
            .zIndex(45)

            ZStack(alignment: .bottom) {
                if let deviceID = store.appPickerDeviceID {
                    Scrim { store.closeAppPicker() }
                    AppPickerSheet(deviceID: deviceID)
                }
            }
            .allowsHitTesting(store.appPickerDeviceID != nil)
            .zIndex(45.5)

            ZStack(alignment: .bottom) {
                if let form = store.form {
                    Scrim { store.closeForm() }
                    FormSheet(spec: form)
                }
            }
            .allowsHitTesting(store.form != nil)
            .zIndex(46)

            ZStack {
                if let confirm = store.confirm {
                    Scrim(opacity: 0.44) { store.closeConfirm() }
                    ConfirmDialog(
                        spec: confirm,
                        onConfirm: store.resolveConfirm,
                        onCancel: store.closeConfirm
                    )
                }
            }
            .allowsHitTesting(store.confirm != nil)
            .zIndex(48)

            if let toast = store.toast {
                Toast(text: toast, style: store.toastStyle)
                    .padding(.bottom, SK.tabBarHeight + 24)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .zIndex(60)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch store.tab {
        case .home: HomeView()
        case .blocking: BlockingView()
        case .parental: ParentalView()
        case .menu: MenuView()
        }
    }

    @ViewBuilder
    private func pushedScreen(_ route: Route) -> some View {
        switch route {
        case .device(let id):
            DeviceDetailView(deviceID: id)
        case .detail(let spec):
            DetailView(spec: spec)
        case .pairing:
            PairingView()
        }
    }

    private var quickActions: [QuickAction] {
        [
            QuickAction(label: "Block a site",
                        subtitle: "Add a domain to the blocklist",
                        icon: Icons.blockSite) { store.openForm(Forms.blockSite) },
            QuickAction(label: "Allow a site",
                        subtitle: "Let ads through on one site",
                        icon: Icons.allowSite) { store.openForm(Forms.allowSite) },
            QuickAction(label: "Add a device",
                        subtitle: "Pair a phone, tablet or laptop",
                        icon: Icons.device) {
                store.setSheet(false)
                Task { await store.startDeviceClaim() }
            },
        ]
    }

    /// Static detail screen for an already-paired box — this one fits the
    /// existing declarative `DetailSpec` pattern fine, unlike the live
    /// discovery list in `PairingView`.
    private var managedBoxDetail: DetailSpec {
        DetailSpec(
            title: store.pairedBox?.boxName ?? "Spark box",
            subtitle: "Paired device",
            note: "",
            rows: [
                DetailRow(label: "Box name", value: store.pairedBox?.boxName ?? ""),
                DetailRow(label: "Address", value: store.pairedBox?.host ?? ""),
                DetailRow(label: "Forget this box", isDanger: true, action: .confirm(ConfirmSpec(
                    title: "Forget this box?",
                    body: "Spark stops controlling it. You can pair again later.",
                    actionLabel: "Forget box",
                    then: .unpairBox
                ))),
            ]
        )
    }
}

#Preview {
    RootView()
}
