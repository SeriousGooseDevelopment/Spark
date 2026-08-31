import Foundation

/// Every form the app can open. Kept together so the copy stays consistent.
enum Forms {
    static let blockSite = FormSpec(
        title: "Block a site",
        subtitle: "Spark will filter this domain everywhere.",
        fields: [
            FormField(id: "domain", label: "Domain", placeholder: "example.com", kind: .domain),
        ],
        primary: "Block site",
        kind: .blockSite
    )

    static let allowSite = FormSpec(
        title: "Allow a site",
        subtitle: "Ads and trackers get through on this domain only.",
        fields: [
            FormField(id: "domain", label: "Domain", placeholder: "example.com", kind: .domain),
        ],
        primary: "Allow site",
        kind: .allowSite
    )

    static func addBlockedSite(_ deviceID: String) -> FormSpec {
        FormSpec(
            title: "Block a site",
            subtitle: "Blocks this domain on this device only.",
            fields: [
                FormField(id: "domain", label: "Domain", placeholder: "example.com", kind: .domain),
            ],
            primary: "Block site",
            kind: .addBlockedSite(deviceID)
        )
    }

    static func renameDevice(_ id: String) -> FormSpec {
        FormSpec(
            title: "Rename device",
            subtitle: "Only you see this name.",
            fields: [FormField(id: "name", label: "Device name", placeholder: "Device name")],
            primary: "Save name",
            kind: .renameDevice(id)
        )
    }

    static let contactSupport = FormSpec(
        title: "Contact support",
        subtitle: "We usually reply within 4 hours.",
        fields: [
            FormField(id: "subject", label: "Subject", placeholder: "What's going on?"),
            FormField(id: "message", label: "Message", placeholder: "Tell us what happened…",
                      kind: .multiline),
        ],
        primary: "Send message",
        kind: .contactSupport
    )

    static func feedback(_ topic: String) -> FormSpec {
        FormSpec(
            title: topic,
            subtitle: "Goes straight to the Spark team.",
            fields: [
                FormField(id: "site", label: "Site or app", placeholder: "example.com",
                          kind: .domain, required: false),
                FormField(id: "details", label: "Details", placeholder: "What should we know?",
                          kind: .multiline),
            ],
            primary: "Send feedback",
            kind: .sendFeedback(topic)
        )
    }

    static let editName = FormSpec(
        title: "Your name",
        subtitle: "Shown on this device and in your weekly report.",
        fields: [FormField(id: "name", label: "Name", placeholder: "Your name")],
        primary: "Save",
        kind: .editProfile("name")
    )

    static let editEmail = FormSpec(
        title: "Your email",
        subtitle: "Where reports and receipts are sent.",
        fields: [FormField(id: "email", label: "Email", placeholder: "you@example.com", kind: .email)],
        primary: "Save",
        kind: .editProfile("email")
    )

    static let changePassword = FormSpec(
        title: "Change password",
        subtitle: "Use at least 8 characters.",
        fields: [
            FormField(id: "current", label: "Current password", placeholder: "••••••••", kind: .password),
            FormField(id: "new", label: "New password", placeholder: "••••••••", kind: .password),
        ],
        primary: "Update password",
        kind: .changePassword
    )
}

/// Pushed content screens that are pure reading material.
enum Articles {
    private static func article(_ title: String, _ body: String) -> DetailRow {
        DetailRow(label: title, action: .push(DetailSpec(
            title: title, subtitle: "Help article", note: "Was this useful? Contact support if not.",
            rows: [], body: body
        )))
    }

    static let gettingStarted = DetailSpec(
        title: "Getting started",
        subtitle: "6 articles",
        note: "Still stuck? Contact support from the Help & support screen.",
        rows: [
            article("What Spark blocks", "Spark filters ads, trackers, pop-ups and cookie banners in every app and browser on your device. It works by matching requests against filter lists that update in the background, so nothing you do has to change.\n\nBlocking happens on device. Spark never sees the pages you visit."),
            article("Turning blocking on", "Open Home and tap the big button in the middle of the dial. When it shows two bars, blocking is on. Tap it again to pause.\n\nPausing is per device and stays paused until you turn it back on."),
            article("Choosing what to block", "Blocking Controls lists four categories: ads, trackers, pop-ups and cookie banners. Turn any of them off if a site you rely on stops working.\n\nMost broken pages are fixed by allowing that one site instead — see \"Allowing a site\"."),
            article("Allowing a site", "If a page misbehaves, add it to Allowed sites. Spark stops filtering that domain and leaves everything else alone.\n\nYou can remove an allowed site at any time from the same list."),
            article("Per-app rules", "Some apps have their own browsers. Per-app rules let you pause Spark inside one app without affecting the rest of the system.\n\nTap any app in the list to switch it between Blocking and Paused."),
            article("Filter lists", "Filter lists are the rules Spark matches against. Spark Essentials is on by default and covers most of the web. Add more lists from Browse all if you want tighter filtering.\n\nMore lists means more matching, which can slow page loads slightly."),
        ]
    )

    static let notWorking = DetailSpec(
        title: "Blocking not working",
        subtitle: "4 articles",
        note: "If none of these help, send us the site and we'll add a rule.",
        rows: [
            article("Ads still appear", "First check that blocking is on — the Home dial shows the current state. Then check whether the site is in your Allowed sites list.\n\nIf neither explains it, the ad may be served from the same domain as the content, which filter lists deliberately avoid breaking."),
            article("A page looks broken", "Turn off Cookie banners first, then Pop-ups — those two break layouts most often.\n\nIf the page is still broken, allow the site and let us know so we can fix the rule for everyone."),
            article("Video ads get through", "Some video ads are stitched into the stream itself, so there is no separate request to block. Spark cannot remove those without breaking playback.\n\nEverything served as a separate request is blocked normally."),
            article("One app ignores Spark", "Check Per-app rules in Blocking Controls — that app may be paused.\n\nA handful of apps ship their own network stack and bypass system filtering entirely. Those are listed as unsupported."),
        ]
    )

    static let managingDevices = DetailSpec(
        title: "Managing devices",
        subtitle: "5 articles",
        note: "Devices you remove stop being filtered immediately.",
        rows: [
            article("Adding a device", "Open Parental Controls and tap Add a device to pick from devices seen on your network. Spark can only add parental controls to a device it can actually identify on your Wi-Fi.\n\nNew devices start with no daily limit and content filtering off."),
            article("Daily screen time", "Open a device and tap Daily screen time. The usage bar on that screen fills as the limit is used up, and reads \"Limit reached\" once it's spent — at which point the device's internet access is actually cut off, not just tracked.\n\nSetting a shorter limit than the time already used shows the limit as reached straight away."),
            article("Bedtime", "Bedtime cuts off the device's internet access at a set time each evening and restores it at 7:00 AM. Set it to Off to disable it.\n\nBedtime and daily limits are independent — whichever comes first applies."),
            article("Content filters", "Strict blocks adult content, enables Safe Search, and blocks unsafe/phishing sites. Moderate blocks unsafe/phishing sites only. Off disables all content filtering but leaves ad blocking on.\n\nContent filters are per device, not per account."),
            article("Removing a device", "Open the device and tap Remove device. Spark stops filtering on it and its limits are deleted.\n\nYou can add it back later, but its limits will start from the defaults."),
        ]
    )
}
