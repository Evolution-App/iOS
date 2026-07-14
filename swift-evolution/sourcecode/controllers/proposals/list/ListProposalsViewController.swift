import UIKit

final class ListProposalsViewController: BaseViewController {

    // Private IBOutlets
    @IBOutlet private(set) weak var tableView: UITableView!
    @IBOutlet private(set) weak var footerView: UIView!
    @IBOutlet private(set) weak var filterHeaderView: FilterHeaderView!
    @IBOutlet private(set) weak var filterHeaderViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet private(set) weak var settingsBarButtonItem: UIBarButtonItem?

    private var timer = Timer()
    private let viewModel = ProposalListViewModel()
    private lazy var coordinator = ProposalsCoordinator(
        listViewController: self,
        peopleProvider: { [weak self] in self?.viewModel.people ?? [:] },
        proposalProvider: { [weak self] id in self?.viewModel.proposal(id: id) }
    )

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshControl.addTarget(self, action: #selector(pullToRefresh(_:)), for: .valueChanged)

        tableView.registerNib(withClass: ProposalTableViewCell.self)
        tableView.registerNib(withClass: ProposalListHeaderTableViewCell.self)

        tableView.estimatedRowHeight = 164
        tableView.estimatedSectionHeaderHeight = 44.0
        tableView.rowHeight = UITableView.automaticDimension

        tableView.addSubview(refreshControl)

        filterHeaderView.statusFilterView.delegate = self
        filterHeaderView.languageVersionFilterView.delegate = self
        filterHeaderView.searchBar.delegate = self
        filterHeaderView.clipsToBounds = true

        filterHeaderView.filterButton.addTarget(self, action: #selector(filterButtonAction(_:)), for: .touchUpInside)
        filterHeaderView.filteredByButton.addTarget(self, action: #selector(filteredByButtonAction(_:)), for: .touchUpInside)

        filterHeaderView.filterLevel = .without

        viewModel.onChange = { [weak self] in
            self?.reloadFilteredTable()
        }

        registerNotifications()
        coordinator.bindProfileDismissalToProposalDetail()
        getProposalList()

        reachability?.whenReachable = { [weak self] _ in
            if self?.viewModel.isEmpty == true {
                self?.getProposalList()
            }
        }

        reachability?.whenUnreachable = { [weak self] _ in
            if self?.viewModel.isEmpty == true {
                self?.showNoConnection = true
            }
        }

        if let title = Environment.title, title.isEmpty == false {
            self.title = title
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.topItem?.setRightBarButton(settingsBarButtonItem, animated: true)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        filterHeaderViewHeightConstraint.constant = filterHeaderView.heightForView
    }

    private func layoutFilterHeaderView() {
        UIView.animate(withDuration: 0.25) {
            self.filterHeaderViewHeightConstraint.constant = self.filterHeaderView.heightForView
            self.view.layoutIfNeeded()
        }
    }

    deinit {
        removeNotifications()
    }

    override func retryButtonAction(_ sender: UIButton) {
        super.retryButtonAction(sender)
        getProposalList()
    }

    // MARK: - Notifications

    func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveNotification(_:)),
            name: NSNotification.Name.URLScheme,
            object: nil
        )
    }

    func removeNotifications() {
        NotificationCenter.default.removeObserver(NSNotification.Name.URLScheme)
    }

    @objc func didReceiveNotification(_ notification: Notification) {
        guard notification.name == Notification.Name.URLScheme else {
            return
        }
        coordinator.handlePendingNavigation()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ProposalDetailViewController {
            let selected = tableView.indexPathForSelectedRow.flatMap { viewModel.proposal(at: $0.row) }
            coordinator.prepareProposalDetail(destination: destination, sender: sender, selectedProposal: selected)
        } else if let destination = segue.destination as? ProfileViewController {
            coordinator.prepareProfile(destination: destination, sender: sender)
        }
    }

    // MARK: - Requests

    private func getProposalList() {
        guard let reachability = reachability, reachability.connection != .none else {
            refreshControl.endRefreshing()
            showNoConnection = true
            return
        }

        showNoConnection = false
        refreshControl.forceShowAnimation()

        viewModel.loadProposals { [weak self] result in
            guard let self = self else {
                return
            }

            if self.refreshControl.isRefreshing {
                self.refreshControl.endRefreshing()
            }

            switch result {
            case .failure(let error):
                print("Error: \(error)")

            case .success:
                self.filterHeaderView?.statusSource = self.viewModel.statusOrderSource
                self.filterHeaderView?.languageVersionSource = self.viewModel.languageVersions
                self.syncPeopleCache()
                self.tableView.reloadData()

                if UIDevice.current.userInterfaceIdiom == .pad,
                   let first = self.viewModel.proposals.first {
                    self.coordinator.showProposalDetail(first)
                }

                if !Navigation.shared.isClear {
                    self.coordinator.handlePendingNavigation()
                }
            }
        }
    }

    private func syncPeopleCache() {
        (UIApplication.shared.delegate as? AppDelegate)?.people = viewModel.people
    }

    // MARK: - Actions

    @objc func filterButtonAction(_ sender: UIButton?) {
        guard let sender = sender else {
            return
        }

        sender.isSelected = !sender.isSelected
        filterHeaderView.filterLevel = .without

        if !sender.isSelected {
            filterHeaderView.filteredByButton.isSelected = false
            viewModel.setFiltersActive(false)
        } else {
            filterHeaderView.filterLevel = .filtered
            viewModel.setFiltersActive(true)

            if let selected = filterHeaderView.statusFilterView.indexPathsForSelectedItems, selected.count > 0 {
                filterHeaderView.filterLevel = .status
                if selected(status: .implemented) {
                    filterHeaderView.filterLevel = .version
                }
                filterHeaderView.filteredByButton.isSelected = true
            }
        }

        layoutFilterHeaderView()
    }

    @objc func filteredByButtonAction(_ sender: UIButton?) {
        guard let sender = sender else {
            return
        }

        sender.isSelected = !sender.isSelected
        filterHeaderView.filterLevel = sender.isSelected ? .status : .filtered

        if let selected = filterHeaderView.statusFilterView.indexPathsForSelectedItems,
           selected.count > 0,
           sender.isSelected {
            filterHeaderView.filterLevel = selected(status: .implemented) ? .version : .status
        }

        layoutFilterHeaderView()
    }

    @objc private func pullToRefresh(_ sender: UIRefreshControl) {
        getProposalList()
    }

    @IBAction private func openSettings() {
        coordinator.showSettings()
    }

    // MARK: - Filters UI Helpers

    private func selected(status: StatusState) -> Bool {
        guard
            let indexPaths = filterHeaderView.statusFilterView.indexPathsForSelectedItems,
            indexPaths.compactMap({ filterHeaderView.statusSource[$0.item] }).contains(status)
        else {
            return false
        }
        return true
    }

    private func reloadFilteredTable() {
        tableView.beginUpdates()
        tableView.reloadSections(IndexSet(integer: 0), with: .fade)
        tableView.endUpdates()
    }
}

// MARK: - UITableView DataSource

extension ListProposalsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.filteredProposals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.cell(forRowAt: indexPath) as ProposalTableViewCell
        cell.delegate = self
        cell.proposal = viewModel.proposal(at: indexPath.row)
        return cell
    }
}

// MARK: - UITableView Delegate

extension ListProposalsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        coordinator.showProposalDetail()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerCell: ProposalListHeaderTableViewCell = tableView.cell()
        headerCell.proposalCount = viewModel.filteredProposals.count
        return headerCell.contentView
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0.01
    }
}

// MARK: - FilterGenericView Delegate

extension ListProposalsViewController: FilterGenericViewDelegate {
    func didSelectFilter(_ view: FilterListGenericView, type: FilterListGenericType, indexPath: IndexPath) {
        switch type {
        case .status:
            if filterHeaderView.statusSource[indexPath.item] == .implemented {
                filterHeaderView.filterLevel = .version
                layoutFilterHeaderView()
            }

            if let item = view.dataSource[indexPath.item] as? StatusState {
                viewModel.selectStatus(item)
            }

        case .version:
            if let version = view.dataSource[indexPath.item] as? String {
                viewModel.selectLanguage(version)
            }

        default:
            break
        }

        filterHeaderView.updateFilterButton(status: viewModel.selectedStatuses)
    }

    func didDeselectFilter(_ view: FilterListGenericView, type: FilterListGenericType, indexPath: IndexPath) {
        let item = view.dataSource[indexPath.item]

        switch type {
        case .status:
            if let indexPaths = view.indexPathsForSelectedItems,
               indexPaths.compactMap({ filterHeaderView.statusSource[$0.item] }).contains(.implemented) == false {
                filterHeaderView.filterLevel = .status
                layoutFilterHeaderView()
            }

            if let status = item as? StatusState {
                viewModel.deselectStatus(status)
            }

        case .version:
            viewModel.deselectLanguage(item.description)

        default:
            break
        }

        filterHeaderView.updateFilterButton(status: viewModel.selectedStatuses)
    }
}

// MARK: - Proposal Delegate

extension ListProposalsViewController: ProposalDelegate {
    func didSelect(person: Person) {
        guard let name = person.name else {
            return
        }
        coordinator.showProfile(viewModel.person(named: name))
    }

    func didSelect(proposal: Proposal) {
        guard let proposal = viewModel.proposal(id: proposal.id) else {
            return
        }
        coordinator.showProposalDetail(proposal)
    }

    func didSelect(implementation: Implementation) {
        coordinator.showImplementation(implementation)
    }
}

// MARK: - UISearchBar Delegate

extension ListProposalsViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard searchText != "" else {
            viewModel.clearSearch()
            return
        }

        if timer.isValid {
            timer.invalidate()
        }

        if ProposalListFiltering.shouldSearchWhileTyping(searchText) {
            timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
                self?.viewModel.applySearch(searchText)
            }
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text,
              query.trimmingCharacters(in: .whitespaces) != ""
        else {
            return
        }
        viewModel.applySearch(query)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()
        searchBar.text = ""
        viewModel.clearSearch()
    }
}
