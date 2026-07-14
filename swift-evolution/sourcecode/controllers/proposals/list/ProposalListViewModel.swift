import Foundation

protocol ProposalListFetching {
    func listProposals(completion: @escaping (ServiceResult<[Proposal]>) -> Void)
}

struct EvolutionProposalFetcher: ProposalListFetching {
    func listProposals(completion: @escaping (ServiceResult<[Proposal]>) -> Void) {
        EvolutionService.listProposals(completion: completion)
    }
}

/// Store for proposal list data, filters, search, and people cache.
final class ProposalListViewModel {

    typealias OnChange = () -> Void

    private let fetcher: ProposalListFetching
    private let statusOrder: [StatusState]

    private(set) var proposals: [Proposal] = []
    private(set) var filteredProposals: [Proposal] = []
    private(set) var people: [String: Person] = [:]
    private(set) var languageVersions: [Version] = []

    private(set) var selectedStatuses: [StatusState] = []
    private(set) var selectedLanguages: [Version] = []
    private(set) var filtersActive = false
    private(set) var searchQuery: String = ""

    var onChange: OnChange?

    var statusOrderSource: [StatusState] {
        statusOrder
    }

    var isEmpty: Bool {
        proposals.isEmpty
    }

    init(
        fetcher: ProposalListFetching = EvolutionProposalFetcher(),
        statusOrder: [StatusState] = ProposalListFiltering.defaultStatusOrder
    ) {
        self.fetcher = fetcher
        self.statusOrder = statusOrder
    }

    // MARK: - Loading

    func loadProposals(completion: @escaping (Result<[Proposal], Error>) -> Void) {
        fetcher.listProposals { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }

            case .success(let proposals):
                DispatchQueue.main.async {
                    self.replaceProposals(proposals)
                    completion(.success(self.proposals))
                }
            }
        }
    }

    func replaceProposals(_ proposals: [Proposal]) {
        self.proposals = ProposalListFiltering.ordered(proposals, by: statusOrder)
        people = ProposalPeopleBuilder.build(from: self.proposals)
        languageVersions = ProposalListFiltering.languageVersions(from: proposals)
        selectedStatuses = []
        selectedLanguages = []
        searchQuery = ""
        refreshFilteredProposals()
    }

    // MARK: - Filters

    func setFiltersActive(_ active: Bool) {
        filtersActive = active
        refreshFilteredProposals()
    }

    func selectStatus(_ status: StatusState) {
        selectedStatuses.append(status)
        if status == .implemented {
            selectedLanguages = []
        }
        refreshFilteredProposals()
    }

    func deselectStatus(_ status: StatusState) {
        _ = selectedStatuses.remove(status)
        refreshFilteredProposals()
    }

    func selectLanguage(_ version: Version) {
        selectedLanguages.append(version)
        refreshFilteredProposals()
    }

    func deselectLanguage(_ version: Version) {
        _ = selectedLanguages.remove(string: version)
        refreshFilteredProposals()
    }

    // MARK: - Search

    func applySearch(_ query: String) {
        searchQuery = query
        refreshFilteredProposals()
    }

    func clearSearch() {
        searchQuery = ""
        refreshFilteredProposals()
    }

    // MARK: - Lookups

    func proposal(at index: Int) -> Proposal? {
        guard filteredProposals.indices.contains(index) else {
            return nil
        }
        return filteredProposals[index]
    }

    func proposal(id: Int) -> Proposal? {
        proposals.get(by: id)
    }

    func person(named name: String) -> Person? {
        people[name]
    }

    func person(username: String) -> Person? {
        people.get(username: username)
    }

    // MARK: - Private

    private func refreshFilteredProposals() {
        let baseline: [Proposal]?
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseline = nil
        } else {
            baseline = ProposalListFiltering.search(proposals, query: searchQuery)
        }

        filteredProposals = ProposalListFiltering.apply(
            to: proposals,
            searchBaseline: baseline,
            selectedStatuses: selectedStatuses,
            selectedLanguages: selectedLanguages,
            filtersActive: filtersActive,
            implementedSelected: selectedStatuses.contains(.implemented),
            statusOrder: statusOrder
        )
        onChange?()
    }
}
