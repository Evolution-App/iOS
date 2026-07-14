import SafariServices
import UIKit

/// Coordinates navigation from the proposals list using existing Routes / Navigation / segues.
final class ProposalsCoordinator {

    weak var listViewController: UIViewController?
    private let peopleProvider: () -> [String: Person]
    private let proposalProvider: (Int) -> Proposal?

    init(
        listViewController: UIViewController? = nil,
        peopleProvider: @escaping () -> [String: Person],
        proposalProvider: @escaping (Int) -> Proposal?
    ) {
        self.listViewController = listViewController
        self.peopleProvider = peopleProvider
        self.proposalProvider = proposalProvider
    }

    // MARK: - Deep links (Routes → Navigation)

    func handlePendingNavigation(_ navigation: Navigation = .shared) {
        guard !navigation.isClear, let host = navigation.host, let value = navigation.value else {
            return
        }

        switch host {
        case .proposal:
            let id: Int = value.regex(Config.Common.Regex.proposalID)
            guard let proposal = proposalProvider(id) else {
                return
            }
            showProposalDetail(proposal)

        case .profile:
            guard let person = peopleProvider().get(username: value) else {
                return
            }
            showProfile(person)

        case .implementation:
            break
        }
    }

    func bindProfileDismissalToProposalDetail() {
        ProfileViewController.dismissCallback = { [weak self] object in
            guard let proposal = object as? Proposal else {
                return
            }
            self?.showProposalDetail(proposal)
        }
    }

    // MARK: - Screen presentation

    func showProposalDetail(_ proposal: Proposal? = nil) {
        let source = detailPresentationSource
        Config.Segues.proposalDetail.performSegue(in: source, with: proposal, split: true)
    }

    func showProfile(_ person: Person?) {
        Config.Segues.profile.performSegue(in: listViewController, with: person, formSheet: true)
    }

    func showSettings() {
        openViewController(of: "SettingsStoryboardID")
    }

    func showImplementation(_ implementation: Implementation) {
        guard let url = URL(string: "\(Config.Base.URL.GitHub.base)/\(implementation.path)") else {
            return
        }
        let safariViewController = SFSafariViewController(url: url)
        listViewController?.present(safariViewController, animated: true)
    }

    func prepareProposalDetail(
        destination: ProposalDetailViewController,
        sender: Any?,
        selectedProposal: Proposal?
    ) {
        let item: Proposal?
        if let proposal = sender as? Proposal {
            item = proposal
        } else {
            item = selectedProposal
        }

        if let proposal = item {
            destination.proposal = proposal
            if !Navigation.shared.isClear {
                Navigation.shared.clear()
            }
        }
    }

    func prepareProfile(destination: ProfileViewController, sender: Any?) {
        guard let person = sender as? Person else {
            return
        }
        destination.profile = person
    }

    // MARK: - Private

    private var detailPresentationSource: UIViewController? {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return listViewController?.splitViewController ?? listViewController
        }
        return listViewController
    }

    private func openViewController(of storyboardID: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: storyboardID)

        if UIDevice.current.userInterfaceIdiom == .pad {
            let navigationController = UINavigationController(rootViewController: controller)
            navigationController.modalPresentationStyle = .formSheet
            listViewController?.present(navigationController, animated: true)
        } else {
            listViewController?.navigationController?.pushViewController(controller, animated: true)
        }
    }
}
