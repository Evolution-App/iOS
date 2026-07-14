import Foundation

/// Builds the people cache used by profile deep links and author/manager taps.
enum ProposalPeopleBuilder {

    static func build(from proposals: [Proposal]) -> [String: Person] {
        var people: [String: Person] = [:]
        var proposalsPeople = People()

        proposals.forEach { proposal in
            proposal.authors?.forEach { author in
                proposalsPeople.append(author)
            }

            if let reviewManager = proposal.reviewManager {
                proposalsPeople.append(reviewManager)
            }
        }

        proposalsPeople.forEach { person in
            guard let name = person.name, name.isEmpty == false else {
                return
            }

            guard people[name] == nil else {
                return
            }

            people[name] = person

            guard var user = people[name] else {
                return
            }

            user.id = UUID().uuidString
            user.asAuthor = proposals.filter(author: user)
            user.asManager = proposals.filter(manager: user)

            people[name] = user
        }

        return people
    }
}
