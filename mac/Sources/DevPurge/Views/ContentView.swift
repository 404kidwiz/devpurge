import SwiftUI

public struct ContentView: View {
    @ObservedObject var viewModel: DevPurgeViewModel
    @ObservedObject private var license = LicenseManager.shared

    public init(viewModel: DevPurgeViewModel = DevPurgeViewModel()) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { windowGeo in
            let width = windowGeo.size.width
            let sidePad = max(20, min(40, width * 0.035))
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerView

                    if let lowDiskMsg = viewModel.lowDiskWarningText {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.danger)
                            Text(lowDiskMsg)
                                .font(Theme.bodyFont(size: 13))
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Button("Scan & Select Safe") {
                                viewModel.scanAndSelectSafe()
                            }
                            .buttonStyle(ZineButtonStyle(kind: .secondary, size: 12))
                            .disabled(viewModel.isScanning || viewModel.isCleaning)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paper(Theme.warnBg, seed: 29, shadow: false)
                    }

                    if !viewModel.cleanupResults.isEmpty {
                        ResultsView(viewModel: viewModel)
                    }

                    heroAndMetrics(width: width)

                    StorageBreakdownBarView(targets: viewModel.targets)

                    if viewModel.apfsReport.hasSnapshots {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundColor(Theme.warn)
                            Text(viewModel.apfsReport.explanation)
                                .font(Theme.bodyFont(size: 13))
                                .foregroundColor(Theme.ink)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paper(Theme.warnBg, seed: 31, shadow: false)
                    }

                    inventorySectionView(width: width)

                    footerView
                }
                .padding(.horizontal, sidePad)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                selectionActionBar(width: width)
                    .padding(.horizontal, sidePad)
                    .padding(.vertical, 14)
                    .background(
                        Theme.background
                            .overlay(Rectangle().fill(PaperGrain.image).opacity(Theme.current.isDark ? 0.05 : 0.12).blendMode(.multiply))
                            .shadow(color: .black.opacity(Theme.current.isDark ? 0.35 : 0.08), radius: 8, x: 0, y: -3)
                    )
                    .overlay(Rectangle().fill(Theme.line).frame(height: 1.5), alignment: .top)
            }
        }
        .background(Theme.background.overlay(Rectangle().fill(PaperGrain.image).opacity(Theme.current.isDark ? 0.05 : 0.12).blendMode(.multiply)).ignoresSafeArea())
        .sheet(isPresented: $viewModel.isReviewPresented) {
            ReviewModalView(viewModel: viewModel).themed()
        }
        .sheet(isPresented: $viewModel.isLicenseSheetPresented) {
            LicenseActivationView().themed()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("DevPurge")
                .font(Theme.headingFont(size: 26))
                .foregroundColor(Theme.ink)

            Text(license.badgeText)
                .font(Theme.headingFont(size: 13))
                .foregroundColor(license.canClean ? Theme.notes[0].fg : Theme.warn)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .paper(license.canClean ? Theme.notes[0].bg : Theme.warnBg, seed: 3, depth: 2, shadow: false)
                .rotationEffect(.degrees(-1.5))

            Spacer()

            PalettePicker(compact: true)
                .padding(.trailing, 4)

            Button(action: { viewModel.isLicenseSheetPresented = true }) {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.licenseManager.status.isActive ? "checkmark.seal.fill" : "key")
                        .font(.system(size: 11, weight: .semibold))
                    Text(viewModel.licenseManager.status.isActive ? "Licensed" : "License")
                }
            }
            .buttonStyle(ZineButtonStyle(kind: .secondary, size: 13))
            .help("Manage license key")

            Text("On this Mac · Local only")
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(Theme.muted)
        }
        .padding(.bottom, 10)
        .overlay(Rectangle().fill(Theme.line).frame(height: 1.5), alignment: .bottom)
    }

    // MARK: - Hero + metric notes

    @ViewBuilder
    private func heroAndMetrics(width: CGFloat) -> some View {
        if width >= 840 {
            HStack(alignment: .center, spacing: 24) {
                heroText.frame(maxWidth: .infinity, alignment: .leading)
                StorageMetricsView(viewModel: viewModel)
                    .frame(width: min(600, width * 0.56))
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                heroText
                StorageMetricsView(viewModel: viewModel, stacked: width < 640)
            }
        }
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text("A ") + Text("little").underline(true, color: Theme.primary) + Text(" breathing room."))
                .font(Theme.headingFont(size: 40))
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("See what’s taking up space. Clear only what you choose.")
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(Theme.ink.opacity(0.85))

            HStack(spacing: 12) {
                Button(action: { viewModel.scan() }) {
                    HStack(spacing: 10) {
                        if viewModel.isScanning {
                            ProgressView().controlSize(.small)
                        }
                        Text(viewModel.isScanning ? "Scanning…" : "Scan storage")
                    }
                    .frame(minWidth: 190)
                }
                .buttonStyle(ZineButtonStyle(kind: .primary, size: 20))
                .disabled(viewModel.isScanning || viewModel.isCleaning)
                .keyboardShortcut("r", modifiers: .command)

                Button(action: { viewModel.chooseProjectFolder() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add project folder…")
                    }
                }
                .buttonStyle(ZineButtonStyle(kind: .secondary, size: 13))
                .disabled(viewModel.isScanning || viewModel.isCleaning)
                .help("Scan a workspace folder for stale node_modules, .venv, and Cargo target directories")
            }
            .padding(.top, 4)

            if !viewModel.config.projectScanRoots.isEmpty {
                HStack(spacing: 6) {
                    Text("Project roots (>\(viewModel.config.staleProjectDays)d idle):")
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(Theme.muted)
                    ForEach(viewModel.config.projectScanRoots, id: \.self) { root in
                        let name = URL(fileURLWithPath: root).lastPathComponent
                        Button(action: { viewModel.removeProjectRoot(root) }) {
                            HStack(spacing: 4) {
                                Text(name)
                                    .font(Theme.monoFont(size: 11))
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.surface))
                            .overlay(Capsule().stroke(Theme.ink.opacity(0.45), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(root) from project scan roots")
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Inventory

    private func inventorySectionView(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if width >= 800 {
                HStack(alignment: .center, spacing: 14) {
                    inventoryTitle
                    Spacer(minLength: 10)
                    filterControl
                    searchField
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    inventoryTitle
                    HStack { filterControl; Spacer() }
                    searchField.frame(maxWidth: .infinity)
                }
            }

            HStack {
                Text(viewModel.statusMessage)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(viewModel.isStatusError ? Theme.danger : Theme.muted)
                Spacer()
                batchSelectHelpers
                Text(viewModel.scannedAt.map { "Scanned \($0.formatted(date: .omitted, time: .shortened))" } ?? "Not scanned yet")
                    .font(Theme.bodyFont(size: 12))
                    .foregroundColor(Theme.muted)
            }

            if viewModel.targets.isEmpty {
                emptyPlaceholderView
            } else if viewModel.filteredTargets.isEmpty {
                filteredEmptyPlaceholderView
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(viewModel.filteredTargets.enumerated()), id: \.element.id) { index, target in
                        TargetRowView(
                            target: target,
                            isSelected: viewModel.selectedTargetIDs.contains(target.id),
                            isPruning: viewModel.pruningTargetID == target.id,
                            seed: index + 11,
                            onToggle: { viewModel.toggleSelection(for: target) },
                            onIgnoreCategory: { viewModel.ignoreCategory(target.category) },
                            onNativePrune: { viewModel.runNativeToolPrune(for: target) }
                        )
                    }
                }
            }
        }
    }

    private var inventoryTitle: some View {
        Text("Know what stays. Choose what goes.")
            .font(Theme.headingFont(size: 26))
            .foregroundColor(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var filterControl: some View {
        HStack(spacing: 0) {
            ForEach(FilterOption.allCases) { opt in
                let on = viewModel.filter == opt
                Button(action: { viewModel.filter = opt }) {
                    Text(opt.rawValue)
                        .font(Theme.headingFont(size: 14))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundColor(on ? Theme.onAccent : Theme.ink)
                        .background(RoundedRectangle(cornerRadius: 6).fill(on ? Theme.accent : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.ink.opacity(0.4), lineWidth: 1.5))
    }

    @ViewBuilder
    private var batchSelectHelpers: some View {
        if !viewModel.targets.isEmpty {
            HStack(spacing: 6) {
                if viewModel.eligibleCount > 0 {
                    Button("Select all") { viewModel.selectAllEligible() }
                    Text("·").foregroundColor(Theme.muted)
                    Button("Deselect") { viewModel.deselectAll() }
                    Text("·").foregroundColor(Theme.muted)
                }
                Button("Copy report") { viewModel.copyScanReportToClipboard() }
                    .help("Copy Markdown storage report to clipboard")
            }
            .buttonStyle(.plain)
            .font(Theme.bodyFont(size: 12))
            .foregroundColor(Theme.accent)
            .padding(.trailing, 10)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.muted)
            TextField("Search paths or groups", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(Theme.ink)
            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 200, maxWidth: 300)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.ink.opacity(0.4), lineWidth: 1.5))
    }

    private var emptyPlaceholderView: some View {
        VStack(spacing: 10) {
            Dashes(color: Theme.primary)
            Text("Start with a clear picture.")
                .font(Theme.headingFont(size: 24))
                .foregroundColor(Theme.ink)
            Text("Your caches, app installers and package stores will appear here.\nActive and unsupported locations stay protected.")
                .font(Theme.bodyFont(size: 13))
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
        .paper(Theme.surface, seed: 21)
    }

    private var filteredEmptyPlaceholderView: some View {
        VStack(spacing: 10) {
            Text("No matching locations.")
                .font(Theme.headingFont(size: 22))
                .foregroundColor(Theme.ink)
            Text("Try switching the filter tab or clearing your search query.")
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(Theme.muted)
            Button("Reset filters") {
                viewModel.filter = .all
                viewModel.searchQuery = ""
            }
            .buttonStyle(ZineButtonStyle(kind: .secondary, size: 14))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .paper(Theme.surface, seed: 22, shadow: false)
    }

    // MARK: - Selection bar

    private func selectionActionBar(width: CGFloat) -> some View {
        Group {
            if width >= 720 {
                HStack(alignment: .center, spacing: 18) {
                    selectionSummary
                    Spacer(minLength: 12)
                    trashToggle
                    reviewButton
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    selectionSummary
                    HStack { trashToggle; Spacer(); reviewButton }
                }
            }
        }
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 12) {
                Text(viewModel.selectedTargetIDs.isEmpty
                     ? "Nothing selected"
                     : "\(ByteFormat.string(viewModel.totalSelectedBytes)) selected")
                    .font(Theme.headingFont(size: 28))
                    .foregroundColor(viewModel.selectedTargetIDs.isEmpty ? Theme.muted : Theme.accent)
                    .monospacedDigit()
                if !viewModel.selectedTargetIDs.isEmpty {
                    Dashes(color: Theme.primary).rotationEffect(.degrees(90))
                }
            }
            Text("Stored sizes are not guaranteed freed space.")
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(Theme.muted)
        }
    }

    private var trashToggle: some View {
        Button(action: { viewModel.rescueMode.toggle() }) {
            HStack(spacing: 8) {
                ZineCheckbox(isOn: viewModel.rescueMode)
                Text("Move files to Trash")
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(Theme.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.rescueMode ? .isSelected : [])
    }

    private var reviewButton: some View {
        Button("Review selection") { viewModel.prepareReview() }
            .buttonStyle(ZineButtonStyle(kind: .primary, size: 18))
            .disabled(viewModel.selectedTargetIDs.isEmpty || viewModel.isCleaning)
    }

    private var footerView: some View {
        HStack {
            Text("DevPurge / Storage desk")
            Spacer()
            Text("Nothing runs automatically from this dashboard.")
        }
        .font(Theme.bodyFont(size: 12))
        .foregroundColor(Theme.muted)
        .padding(.top, 6)
    }
}
