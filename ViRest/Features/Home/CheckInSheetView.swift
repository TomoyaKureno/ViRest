//
//  CheckInSheetView.swift
//  ViRest
//
//  Created by Joshua Valentine Manik on 13/03/26.
//

import SwiftUI

struct CheckInSheetView: View {
    @ObservedObject var viewModel: CheckInSheetViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Handle bar
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)

                    switch viewModel.state {
                    case .form:
                        formContent
                    case .result:
                        resultContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // ─── FORM ───────────────────────────────────────
    private var formContent: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppPalette.accent)
                Text("How did it go?")
                    .font(AppTypography.title(24))
                    .foregroundStyle(.white)
                Text("Your feedback helps us fine-tune your plan.")
                    .font(AppTypography.body(14))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Difficulty
            questionCard(title: "How difficult was it?", icon: "flame") {
                AnyView(pickerRow(selection: $viewModel.difficulty, cases: ActivityDifficulty.allCases))
            }

            // Fatigue
            questionCard(title: "How tired do you feel?", icon: "battery.25") {
                AnyView(pickerRow(selection: $viewModel.fatigue, cases: FatigueLevel.allCases))
            }

            // Pain
            questionCard(title: "Any pain during activity?", icon: "cross.circle") {
                AnyView(pickerRow(selection: $viewModel.painLevel, cases: PainLevel.allCases))
            }

            // Discomfort areas (conditional)
            if viewModel.painLevel != .noPain {
                questionCard(title: "Where did you feel discomfort?", icon: "figure.stand") {
                    AnyView(
                        FlowLayout(spacing: 8) {
                            ForEach(DiscomfortArea.allCases) { area in
                                chipToggle(
                                    label: area.displayName,
                                    selected: viewModel.discomfortAreas.contains(area)
                                ) {
                                    if viewModel.discomfortAreas.contains(area) {
                                        viewModel.discomfortAreas.remove(area)
                                    } else {
                                        viewModel.discomfortAreas.insert(area)
                                    }
                                }
                            }
                        }
                    )
                }
            }

            // Notes
            questionCard(title: "Additional notes (optional)", icon: "note.text") {
                AnyView(
                    TextField("How did it feel overall?", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...4)
                        .font(AppTypography.body(14))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                )
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppTypography.caption(13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Submit button
            Button {
                viewModel.submit()
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    }
                    Text(viewModel.isLoading ? "Saving..." : "Submit Check-In")
                        .font(AppTypography.body(16))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [AppPalette.auroraA, AppPalette.auroraB],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(viewModel.isLoading)
        }
    }

    // ─── RESULT ─────────────────────────────────────
    private var resultContent: some View {
        VStack(spacing: 20) {
            // Zone indicator
            if let assessment = viewModel.assessment {
                VStack(spacing: 10) {
                    Image(systemName: zoneIcon(assessment.zone))
                        .font(.system(size: 48))
                        .foregroundStyle(zoneColor(assessment.zone))

                    Text(zoneName(assessment.zone))
                        .font(AppTypography.hero(28))
                        .foregroundStyle(zoneColor(assessment.zone))

                    Text(assessment.recommendationText)
                        .font(AppTypography.body(15))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(assessment.reasons, id: \.self) { reason in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.top, 2)
                                Text(reason)
                                    .font(AppTypography.caption(13))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            // New title earned
            if let title = viewModel.newTitleName {
                resultBadgeCard(
                    icon: "crown.fill",
                    color: .yellow,
                    title: "Title Earned",
                    subtitle: title
                )
            }

            // Appreciation message
            if let appreciation = viewModel.appreciationText {
                resultBadgeCard(
                    icon: "hands.clap.fill",
                    color: AppPalette.accent,
                    title: "Great work!",
                    subtitle: appreciation
                )
            }

            // New badges
            if !viewModel.newBadges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("New Badges", systemImage: "rosette")
                        .font(AppTypography.title(18))
                        .foregroundStyle(.white)

                    ForEach(viewModel.newBadges) { badge in
                        resultBadgeCard(
                            icon: "star.fill",
                            color: .orange,
                            title: badge.type.title,
                            subtitle: badge.type.title
                        )
                    }
                }
            }

            // Done button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(AppTypography.body(16))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // ─── HELPERS ────────────────────────────────────
    private func questionCard(title: String, icon: String, content: () -> AnyView) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(AppTypography.body(14))
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
            content()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pickerRow<T: CaseIterable & Identifiable & Hashable & DisplayNamed>(
        selection: Binding<T>,
        cases: [T]
    ) -> some View {
        Picker("", selection: selection) {
            ForEach(cases) { item in
                Text(item.displayName).tag(item)
            }
        }
        .pickerStyle(.menu)
        .tint(AppPalette.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chipToggle(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.caption(13))
                .foregroundStyle(selected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? AppPalette.accent : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    private func resultBadgeCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.body(14))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(AppTypography.caption(13))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func zoneIcon(_ zone: SuitabilityZone) -> String {
        switch zone {
        case .green:  return "checkmark.seal.fill"
        case .yellow: return "exclamationmark.triangle.fill"
        case .red:    return "xmark.octagon.fill"
        }
    }

    private func zoneColor(_ zone: SuitabilityZone) -> Color {
        switch zone {
        case .green:  return .green
        case .yellow: return .yellow
        case .red:    return .red
        }
    }

    private func zoneName(_ zone: SuitabilityZone) -> String {
        switch zone {
        case .green:  return "Green Zone"
        case .yellow: return "Yellow Zone"
        case .red:    return "Red Zone"
        }
    }
}

// Simple flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
            .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? 0
        for subview in subviews {
            let width = subview.sizeThatFits(.unspecified).width
            if x + width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(subview)
            x += width + spacing
        }
        return rows
    }
}

// Protocol to access displayName generically in pickerRow
protocol DisplayNamed { var displayName: String { get } }
extension ActivityDifficulty: DisplayNamed {}
extension FatigueLevel: DisplayNamed {}
extension PainLevel: DisplayNamed {}
