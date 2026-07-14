import Foundation

/// Pure filter and search helpers for the proposals list.
enum ProposalListFiltering {

    static let defaultStatusOrder: [StatusState] = [
        .awaitingReview,
        .scheduledForReview,
        .activeReview,
        .accepted,
        .acceptedWithRevisions,
        .previewing,
        .implemented,
        .returnedForRevision,
        .deferred,
        .rejected,
        .withdrawn
    ]

    /// Applies status/language filters and optional search baseline, then orders results.
    static func apply(
        to proposals: [Proposal],
        searchBaseline: [Proposal]? = nil,
        selectedStatuses: [StatusState],
        selectedLanguages: [Version],
        filtersActive: Bool,
        implementedSelected: Bool,
        statusOrder: [StatusState] = defaultStatusOrder
    ) -> [Proposal] {
        var filtered = searchBaseline ?? proposals

        if filtersActive {
            if !selectedStatuses.isEmpty {
                var exceptions: [StatusState] = [.implemented]
                if implementedSelected && selectedLanguages.isEmpty {
                    exceptions = []
                }

                filtered = filtered.filter(by: selectedStatuses, exceptions: exceptions).sort(.descending)
            }

            if implementedSelected && !selectedLanguages.isEmpty {
                let implemented = proposals.filter(by: selectedLanguages).filter(status: .implemented)
                filtered.append(contentsOf: implemented)
            }
        }

        return filtered.distinct().filter(by: statusOrder)
    }

    /// Text proposals by free-form query (id, title, author, etc.).
    static func search(_ proposals: [Proposal], query: String) -> [Proposal] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return proposals
        }
        return proposals.filter(by: trimmed)
    }

    /// Whether search should run automatically as the user types.
    static func shouldSearchWhileTyping(_ query: String, minimumCharacters: Int = 4) -> Bool {
        query.count > (minimumCharacters - 1)
    }

    static func languageVersions(from proposals: [Proposal]) -> [Version] {
        proposals.compactMap { $0.status.version }.removeDuplicates().sorted()
    }

    static func ordered(_ proposals: [Proposal], by statusOrder: [StatusState] = defaultStatusOrder) -> [Proposal] {
        proposals.filter(by: statusOrder)
    }
}
