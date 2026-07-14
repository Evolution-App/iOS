import XCTest
@testable import swift_evolution

final class ProposalListFilteringTests: XCTestCase {

    private func proposal(
        id: Int,
        title: String = "Title",
        state: StatusState,
        version: Version? = nil,
        summary: String? = nil,
        authors: [Person]? = nil
    ) -> Proposal {
        Proposal(
            id: id,
            title: title,
            status: Status(version: version, state: state, start: nil, end: nil),
            summary: summary,
            authors: authors
        )
    }

    func testOrderedPreservesStatusPriority() {
        let proposals = [
            proposal(id: 3, state: .implemented),
            proposal(id: 1, state: .activeReview),
            proposal(id: 2, state: .accepted)
        ]

        let ordered = ProposalListFiltering.ordered(proposals)
        XCTAssertEqual(ordered.map { $0.id }, [1, 2, 3])
    }

    func testSearchMatchesTitleAndId() {
        let proposals = [
            proposal(id: 25, title: "Opaque Result Types", state: .accepted),
            proposal(id: 10, title: "Other", state: .rejected)
        ]

        XCTAssertEqual(ProposalListFiltering.search(proposals, query: "Opaque").map { $0.id }, [25])
        XCTAssertEqual(ProposalListFiltering.search(proposals, query: "25").map { $0.id }, [25])
        XCTAssertEqual(ProposalListFiltering.search(proposals, query: "   ").map { $0.id }, [25, 10])
    }

    func testShouldSearchWhileTypingRequiresFourCharacters() {
        XCTAssertFalse(ProposalListFiltering.shouldSearchWhileTyping("abc"))
        XCTAssertTrue(ProposalListFiltering.shouldSearchWhileTyping("abcd"))
    }

    func testApplyFiltersBySelectedStatuses() {
        let proposals = [
            proposal(id: 1, state: .accepted),
            proposal(id: 2, state: .rejected),
            proposal(id: 3, state: .implemented, version: "5.0")
        ]

        let filtered = ProposalListFiltering.apply(
            to: proposals,
            selectedStatuses: [.accepted, .rejected],
            selectedLanguages: [],
            filtersActive: true,
            implementedSelected: false
        )

        XCTAssertEqual(Set(filtered.map { $0.id }), Set([1, 2]))
    }

    func testApplyIncludesImplementedVersionsWhenSelected() {
        let proposals = [
            proposal(id: 1, state: .accepted),
            proposal(id: 2, state: .implemented, version: "5.0"),
            proposal(id: 3, state: .implemented, version: "5.1")
        ]

        let filtered = ProposalListFiltering.apply(
            to: proposals,
            selectedStatuses: [.accepted, .implemented],
            selectedLanguages: ["5.1"],
            filtersActive: true,
            implementedSelected: true
        )

        XCTAssertEqual(Set(filtered.map { $0.id }), Set([1, 3]))
    }

    func testLanguageVersionsAreUniqueAndSorted() {
        let proposals = [
            proposal(id: 1, state: .implemented, version: "5.1"),
            proposal(id: 2, state: .implemented, version: "5.0"),
            proposal(id: 3, state: .implemented, version: "5.1"),
            proposal(id: 4, state: .accepted, version: nil)
        ]

        XCTAssertEqual(ProposalListFiltering.languageVersions(from: proposals), ["5.0", "5.1"])
    }

    func testPeopleBuilderIndexesAuthorsAndManagers() {
        let author = Person(
            id: nil,
            name: "Alice",
            link: "https://github.com/alice",
            username: "alice",
            github: nil,
            asAuthor: nil,
            asManager: nil
        )
        let manager = Person(
            id: nil,
            name: "Bob",
            link: "https://github.com/bob",
            username: "bob",
            github: nil,
            asAuthor: nil,
            asManager: nil
        )
        let proposals = [
            proposal(id: 1, state: .accepted, authors: [author]),
            Proposal(
                id: 2,
                title: "Managed",
                status: Status(version: nil, state: .implemented, start: nil, end: nil),
                reviewManager: manager
            )
        ]

        let people = ProposalPeopleBuilder.build(from: proposals)
        XCTAssertEqual(people["Alice"]?.asAuthor?.map { $0.id }, [1])
        XCTAssertEqual(people["Bob"]?.asManager?.map { $0.id }, [2])
        XCTAssertNotNil(people.get(username: "alice"))
    }

    func testViewModelAppliesSearchAndFilters() {
        let viewModel = ProposalListViewModel()
        viewModel.replaceProposals([
            proposal(id: 1, title: "Async Await", state: .accepted),
            proposal(id: 2, title: "Actors", state: .rejected),
            proposal(id: 3, title: "Async Sequences", state: .accepted)
        ])

        viewModel.setFiltersActive(true)
        viewModel.selectStatus(.accepted)
        viewModel.applySearch("Async")

        XCTAssertEqual(viewModel.filteredProposals.map { $0.id }, [3, 1])
    }
}
