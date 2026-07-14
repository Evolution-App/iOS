import Foundation

struct ProposalResponse: Decodable {
    let proposals: [Proposal]
}

struct Proposal: Decodable {
    let id: Int
    let title: String
    let status: Status
    let summary: String?
    let authors: [Person]?
    let warnings: [Warning]?
    let link: String?
    let reviewManager: Person?
    let sha: String?
    let bugs: [Bug]?
    let implementations: [Implementation]?
    
    enum Keys: String, CodingKey {
        case status
        case summary
        case authors
        case id
        case title
        case warnings
        case link
        case reviewManager
        case sha
        case trackingBugs
        case implementation
    }
    
    init(id: Int, link: String) {
        self.init(
            id: id,
            title: "",
            status: Status(version: nil, state: .accepted, start: nil, end: nil),
            link: link
        )
    }

    init(
        id: Int,
        title: String,
        status: Status,
        summary: String? = nil,
        authors: [Person]? = nil,
        warnings: [Warning]? = nil,
        link: String? = nil,
        reviewManager: Person? = nil,
        sha: String? = nil,
        bugs: [Bug]? = nil,
        implementations: [Implementation]? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.summary = summary
        self.authors = authors
        self.warnings = warnings
        self.link = link
        self.reviewManager = reviewManager
        self.sha = sha
        self.bugs = bugs
        self.implementations = implementations
    }

}

extension Proposal {
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        
        let idString = try container.decode(String.self, forKey: .id)
        self.id = ProposalIDFormatter.format(unboxedValue: idString)
        
        self.title              = try container.decode(String.self, forKey: .title)
        self.status             = try container.decode(Status.self, forKey: .status)
        self.summary            = try container.decodeIfPresent(String.self, forKey: .summary)
        self.authors            = try container.decodeIfPresent([Person].self, forKey: .authors)
        self.warnings           = try container.decodeIfPresent([Warning].self, forKey: .warnings)
        self.link               = try container.decodeIfPresent(String.self, forKey: .link)
        self.reviewManager      = try container.decodeIfPresent(Person.self, forKey: .reviewManager)
        self.sha                = try container.decodeIfPresent(String.self, forKey: .sha)
        self.bugs               = try container.decodeIfPresent([Bug].self, forKey: .trackingBugs)
        self.implementations    = try container.decodeIfPresent([Implementation].self, forKey: .implementation)
    }
    
}

extension Proposal: CustomStringConvertible {
    var description: String {
        return String(format: "SE-%04i", self.id)
    }
}

extension Proposal: Comparable {
    public static func == (lhs: Proposal, rhs: Proposal) -> Bool {
        return lhs.id == rhs.id
    }
    
    public static func < (lhs: Proposal, rhs: Proposal) -> Bool {
        return lhs.id < rhs.id
    }
    
    public static func <= (lhs: Proposal, rhs: Proposal) -> Bool {
        return lhs.id <= rhs.id
    }
    
    public static func >= (lhs: Proposal, rhs: Proposal) -> Bool {
        return lhs.id >= rhs.id
    }
    
    public static func > (lhs: Proposal, rhs: Proposal) -> Bool {
        return lhs.id > rhs.id
    }
}
