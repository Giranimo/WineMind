import SwiftUI
import SwiftData

/// In-app "Manage Your Data" screen — exposes all GDPR rights in one place.
struct ManageDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wines: [Wine]

    @EnvironmentObject var consentStore: PrivacyConsentStore
    @EnvironmentObject var profileStore: TasteProfileStore
    @EnvironmentObject var auth: AuthService

    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var deletionStep: AccountDeletionService.Step?
    @State private var isDeleting = false
    @State private var showingPolicy = false

    var body: some View {
        NavigationStack {
            ZStack {
                WineTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        consentToggles
                        dataInventory
                        rightsActions
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                if isDeleting, let step = deletionStep {
                    deletionOverlay(step: step)
                }
            }
            .navigationTitle("Your Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(WineTheme.gold)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingPolicy) {
                PrivacyPolicyView()
            }
            .confirmationDialog(
                "Delete everything?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All My Data", role: .destructive) {
                    deleteEverything()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove your \(wines.count) wines, taste profile, iCloud sync data, and anonymous community contributions. This cannot be undone.")
            }
        }
    }

    // MARK: - Consent

    private var consentToggles: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Permissions")

            ConsentToggleRow(
                icon: "icloud.fill",
                title: "iCloud Sync",
                description: "Back up to your private iCloud",
                isOn: Binding(
                    get: { consentStore.consent.allowsCloudSync },
                    set: { consentStore.updateCloudSync($0) }
                )
            )

            ConsentToggleRow(
                icon: "person.3.fill",
                title: "Community Recommendations",
                description: "Show wines other users rated highly",
                isOn: Binding(
                    get: { consentStore.consent.allowsCommunityRecommendations },
                    set: { consentStore.updateCommunityRecs($0) }
                )
            )

            ConsentToggleRow(
                icon: "arrow.up.heart.fill",
                title: "Contribute Anonymously",
                description: "Send my ratings (no name, no notes) to help others",
                isOn: Binding(
                    get: { consentStore.consent.allowsAnonymousContribution },
                    set: { consentStore.updateAnonymousContribution($0) }
                )
            )

            Button {
                showingPolicy = true
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Read full privacy policy")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .font(.wineCallout)
                .foregroundStyle(WineTheme.gold)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Data Inventory (transparency)

    private var dataInventory: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("What's Stored About You")

            InventoryRow(label: "Wines saved", value: "\(wines.count)")
            InventoryRow(label: "Photos stored", value: "\(wines.filter { $0.photoData != nil }.count)")
            InventoryRow(label: "Tasting notes", value: "\(wines.filter { !$0.notes.isEmpty }.count)")
            InventoryRow(label: "Quiz answers", value: profileStore.hasCompletedQuiz ? "Yes" : "No")
            InventoryRow(label: "iCloud sync", value: consentStore.consent.allowsCloudSync ? "On" : "Off")
            InventoryRow(label: "Community contributions", value: consentStore.consent.allowsAnonymousContribution ? "On" : "Off")
            InventoryRow(label: "Account", value: auth.userName ?? "Apple ID")

            if let acceptedAt = consentStore.consent.acceptedAt {
                InventoryRow(label: "Consent given", value: acceptedAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding()
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - GDPR Rights

    private var rightsActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your Rights")

            RightActionRow(
                icon: "square.and.arrow.down",
                title: "Export My Data",
                subtitle: "Download a JSON file with everything",
                color: WineTheme.gold
            ) {
                exportData()
            }

            RightActionRow(
                icon: "trash.fill",
                title: "Delete Everything",
                subtitle: "Permanently erase all my data",
                color: WineTheme.burgundyLight
            ) {
                showingDeleteConfirmation = true
            }
        }
        .padding()
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(2)
            .foregroundStyle(WineTheme.gold)
    }

    // MARK: - Actions

    private func exportData() {
        Task {
            do {
                let url = try await DataExportService.shared.buildExport(
                    wines: wines,
                    tasteProfile: profileStore.profile,
                    consent: consentStore.consent
                )
                exportURL = url
                showingShareSheet = true
            } catch {
                print("Export failed: \(error)")
            }
        }
    }

    private func deleteEverything() {
        isDeleting = true
        let service = AccountDeletionService()
        Task {
            try? await service.deleteEverything(
                context: modelContext,
                wines: wines
            ) { step in
                Task { @MainActor in
                    deletionStep = step
                }
            }
            auth.signOut()
            isDeleting = false
            dismiss()
        }
    }

    private func deletionOverlay(step: AccountDeletionService.Step) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(WineTheme.gold)
                    .scaleEffect(1.5)
                Text(step.rawValue)
                    .font(.wineCallout)
                    .italic()
                    .foregroundStyle(WineTheme.cream)
            }
            .padding(32)
            .background(WineTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Components

private struct ConsentToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(WineTheme.gold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.wineBody.weight(.semibold))
                    .foregroundStyle(WineTheme.cream)
                Text(description)
                    .font(.wineCaption)
                    .foregroundStyle(WineTheme.mutedText)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(WineTheme.gold)
        }
    }
}

private struct InventoryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.wineCallout)
                .foregroundStyle(WineTheme.mutedText)
            Spacer()
            Text(value)
                .font(.wineCallout.weight(.semibold))
                .foregroundStyle(WineTheme.cream)
        }
        .padding(.vertical, 4)
    }
}

private struct RightActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.wineBody.weight(.semibold))
                        .foregroundStyle(WineTheme.cream)
                    Text(subtitle)
                        .font(.wineCaption)
                        .foregroundStyle(WineTheme.mutedText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(WineTheme.dimText)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
