import SwiftUI

public struct ContentView: View {
    @ObservedObject var viewModel: DevPurgeViewModel

    public init(viewModel: DevPurgeViewModel = DevPurgeViewModel()) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { windowGeo in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header with brand and beta expiry indicator
                    headerView

                    // Intro Hero (Adaptive)
                    introHeroView(width: windowGeo.size.width)

                    // Storage Overview Metrics (Responsive)
                    StorageMetricsView(viewModel: viewModel)

                    // Visual Storage Breakdown Bar
                    StorageBreakdownBarView(targets: viewModel.targets)

                    // APFS Snapshot Notice (if present)
                    if viewModel.apfsReport.hasSnapshots {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundColor(Theme.dynamicWarn)
                                .font(.system(size: 14))

                            Text(viewModel.apfsReport.explanation)
                                .font(Theme.bodyFont(size: 12))
                                .foregroundColor(Theme.dynamicInk)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.dynamicWarnBg.opacity(0.8))
                        .cornerRadius(8)
                    }

                    // Results Section (if any)
                    if !viewModel.cleanupResults.isEmpty {
                        ResultsView(results: viewModel.cleanupResults)
                    }

                    // Inventory Section
                    inventorySectionView(width: windowGeo.size.width)

                    // Selection & Action Bar (Adaptive)
                    selectionActionBar(width: windowGeo.size.width)

                    // Footer
                    footerView
                }
                .padding(.horizontal, max(20, min(40, windowGeo.size.width * 0.04)))
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .background(Theme.dynamicBackground)
        .sheet(isPresented: $viewModel.isReviewPresented) {
            ReviewModalView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isLicenseSheetPresented) {
            LicenseActivationView()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Text("d/")
                    .font(Theme.monoFont(size: 22))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.dynamicAccent)

                Text("DevPurge")
                    .font(Theme.headingFont(size: 19))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.dynamicInk)
            }

            // Beta Expiration Badge
            Text(BetaExpiryGuard.badgeText)
                .font(Theme.monoFont(size: 10))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(BetaExpiryGuard.isExpired ? Theme.dynamicWarnBg : Theme.dynamicSoft)
                .foregroundColor(BetaExpiryGuard.isExpired ? Theme.dynamicWarn : Theme.dynamicAccent)
                .cornerRadius(12)

            // License Status / Activation Trigger
            Button(action: { viewModel.isLicenseSheetPresented = true }) {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.licenseManager.status.isActive ? "checkmark.seal.fill" : "key")
                        .font(.system(size: 10))
                    Text(viewModel.licenseManager.status.isActive ? "Licensed" : "License")
                        .font(Theme.monoFont(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(viewModel.licenseManager.status.isActive ? Theme.dynamicSoft : Theme.dynamicSurface)
                .foregroundColor(viewModel.licenseManager.status.isActive ? Theme.dynamicAccent : Theme.dynamicMuted)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.dynamicLine, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Manage license key")

            Spacer()

            Text("On this Mac · Local only")
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(Theme.dynamicMuted)
        }
        .padding(.bottom, 8)
        .overlay(Divider().background(Theme.dynamicLine), alignment: .bottom)
    }

    private func introHeroView(width: CGFloat) -> some View {
        Group {
            if width >= 660 {
                HStack(alignment: .center) {
                    heroTextContent
                    Spacer(minLength: 16)
                    scanButton
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    heroTextContent
                    scanButton
                }
            }
        }
    }

    private var heroTextContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YOUR STORAGE, UNDERSTOOD")
                .font(Theme.monoFont(size: 11))
                .tracking(1.4)
                .foregroundColor(Theme.dynamicMuted)

            Text("A little breathing room.")
                .font(Theme.headingFont(size: 34))
                .fontWeight(.semibold)
                .foregroundColor(Theme.dynamicInk)

            Text("See what’s taking up space. Clear only what you choose.")
                .font(Theme.bodyFont(size: 15))
                .foregroundColor(Theme.dynamicMuted)
        }
    }

    private var scanButton: some View {
        Button(action: {
            viewModel.scan()
        }) {
            HStack(spacing: 10) {
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(viewModel.isScanning ? "Scanning..." : "Scan storage")
                    .font(Theme.headingFont(size: 14))
                    .fontWeight(.semibold)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.dynamicAccent)
            .foregroundColor(Theme.dynamicOnAccent)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isScanning || viewModel.isCleaning)
    }

    private func inventorySectionView(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Head
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THE INVENTORY")
                        .font(Theme.monoFont(size: 11))
                        .tracking(1.4)
                        .foregroundColor(Theme.dynamicMuted)

                    Text("Know what stays. Choose what goes.")
                        .font(Theme.headingFont(size: 20))
                        .foregroundColor(Theme.dynamicInk)
                }

                Spacer()

                if let date = viewModel.scannedAt {
                    Text("Scanned at \(date.formatted(date: .omitted, time: .standard))")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(Theme.dynamicMuted)
                } else {
                    Text("Not scanned yet")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(Theme.dynamicMuted)
                }
            }

            // Toolbar: Filters & Search (Responsive)
            if width >= 660 {
                HStack(spacing: 12) {
                    filterPills
                    Spacer()
                    batchSelectHelpers
                    searchField
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        filterPills
                        Spacer()
                        batchSelectHelpers
                    }
                    searchField
                        .frame(maxWidth: .infinity)
                }
            }

            // Status message banner
            Text(viewModel.statusMessage)
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(viewModel.isStatusError ? Theme.dynamicRed : Theme.dynamicMuted)
                .padding(.vertical, 2)

            // Content List or Empty View
            if viewModel.targets.isEmpty {
                emptyPlaceholderView
            } else {
                targetListView
            }
        }
    }

    private var filterPills: some View {
        HStack(spacing: 4) {
            ForEach(FilterOption.allCases) { opt in
                Button(action: { viewModel.filter = opt }) {
                    Text(opt.rawValue)
                        .font(Theme.bodyFont(size: 12))
                        .fontWeight(viewModel.filter == opt ? .semibold : .regular)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(viewModel.filter == opt ? Theme.dynamicSoft : Color.clear)
                        .foregroundColor(viewModel.filter == opt ? Theme.dynamicAccent : Theme.dynamicInk)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var batchSelectHelpers: some View {
        if viewModel.eligibleCount > 0 {
            HStack(spacing: 6) {
                Button("Select All") {
                    viewModel.selectAllEligible()
                }
                .font(Theme.bodyFont(size: 11))
                .buttonStyle(.link)

                Text("·")
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(Theme.dynamicMuted)

                Button("Deselect") {
                    viewModel.deselectAll()
                }
                .font(Theme.bodyFont(size: 11))
                .buttonStyle(.link)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.dynamicMuted)
                .font(.system(size: 11))
            TextField("Search paths or groups", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(Theme.bodyFont(size: 12))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(minWidth: 180, maxWidth: 260)
        .background(Theme.dynamicSurface)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.dynamicLine, lineWidth: 1)
        )
    }

    private var emptyPlaceholderView: some View {
        VStack(spacing: 10) {
            Text("⌁")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.dynamicAccent)

            Text("Start with a clear picture.")
                .font(Theme.headingFont(size: 17))
                .foregroundColor(Theme.dynamicInk)

            Text("Your caches, app installers, and package stores will appear here.\nActive and unsupported locations stay protected.")
                .font(Theme.bodyFont(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.dynamicMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
        .background(Theme.dynamicSurface.opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundColor(Theme.dynamicLine)
        )
    }

    private var targetListView: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.filteredTargets) { target in
                TargetRowView(
                    target: target,
                    isSelected: viewModel.selectedTargetIDs.contains(target.id),
                    onToggle: { viewModel.toggleSelection(for: target) },
                    onIgnoreCategory: { viewModel.ignoreCategory(target.category) }
                )

                Divider().background(Theme.dynamicLine)
            }
        }
        .background(Theme.dynamicSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.dynamicLine, lineWidth: 1)
        )
    }

    private func selectionActionBar(width: CGFloat) -> some View {
        Group {
            if width >= 660 {
                HStack(alignment: .center) {
                    selectionSummaryText
                    Spacer(minLength: 16)
                    selectionActionButtons
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    selectionSummaryText
                    selectionActionButtons
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Theme.dynamicSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.dynamicLine, lineWidth: 1)
        )
    }

    private var selectionSummaryText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.selectedTargetIDs.isEmpty
                 ? "Nothing selected"
                 : "\(viewModel.selectedTargetIDs.count) item\(viewModel.selectedTargetIDs.count == 1 ? "" : "s") selected (\(ByteCountFormatter.string(fromByteCount: viewModel.totalSelectedBytes, countStyle: .file)))")
                .font(Theme.headingFont(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(Theme.dynamicInk)

            Text("Stored sizes are not guaranteed freed space.")
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(Theme.dynamicMuted)
        }
    }

    private var selectionActionButtons: some View {
        HStack(spacing: 16) {
            Toggle(isOn: $viewModel.rescueMode) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                    Text("Move files to Trash")
                        .font(Theme.bodyFont(size: 12))
                }
            }
            .toggleStyle(.checkbox)

            Button(action: {
                viewModel.prepareReview()
            }) {
                HStack(spacing: 6) {
                    Text("Review selection")
                        .font(Theme.headingFont(size: 13))
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(viewModel.selectedTargetIDs.isEmpty || BetaExpiryGuard.isExpired ? Theme.dynamicLine : Theme.dynamicAccent)
                .foregroundColor(viewModel.selectedTargetIDs.isEmpty || BetaExpiryGuard.isExpired ? Theme.dynamicMuted : Theme.dynamicOnAccent)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedTargetIDs.isEmpty || viewModel.isCleaning || BetaExpiryGuard.isExpired)
        }
    }

    private var footerView: some View {
        HStack {
            Text("DevPurge / Storage desk")
            Spacer()
            Text("Nothing runs automatically from this dashboard.")
        }
        .font(Theme.monoFont(size: 11))
        .foregroundColor(Theme.dynamicMuted)
        .padding(.top, 12)
        .overlay(Divider().background(Theme.dynamicLine), alignment: .top)
    }
}
