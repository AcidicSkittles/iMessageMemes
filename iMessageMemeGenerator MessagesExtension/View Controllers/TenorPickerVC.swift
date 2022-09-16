//
//  TenorPickerVC.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 8/31/22.
//

import UIKit
import Nuke

public protocol TenorUrlDelegate: AnyObject {
    func didPickUrl(url: String, width: Int, height: Int)
}

class TenorPickerVC: UIViewController, LoadableView {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var collectionView: UICollectionView!
    weak var tenorUrlDelegate: TenorUrlDelegate?
    var loadingView: LoadingView = UIView.fromNib()
    private var becomeResponderAfterExpand: Bool = false
    private let searchRepository = TenorSearchResultsRepository()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureNukeImageLoading()
        self.configureObserver()
        self.configureUI()
        self.setupLoadingView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UI & UI Actions
extension TenorPickerVC {
    private func configureUI() {
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.refresh()
        
        self.searchBar.searchTextField.placeholder = "SEARCH_TENOR".localized
        self.searchBar.delegate = self
        self.searchBar.searchTextField.delegate = self
        
        if let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumLineSpacing = LayoutSettings.spacing
            layout.minimumInteritemSpacing = LayoutSettings.spacing
        }
    }
    
    private func configureObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didTransition),
            name: MessagesViewController.didTransitionKey,
            object: nil
        )
    }
    
    private func configureNukeImageLoading() {
        ImagePipeline.Configuration.isAnimatedImageDataEnabled = true
    }
    
    @objc func didTransition() {
        if self.becomeResponderAfterExpand {
            self.becomeResponderAfterExpand = false
            self.searchBar.becomeFirstResponder()
        }
    }
    
    @objc func refresh() {
        self.searchRepository.search(self.searchBar.text) { _ in
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    func openCaptionBoxWithImageData(gifData: Data) {
        self.loadingView.isHidden = true
        self.searchBar.resignFirstResponder()
        MessagesViewController.shared.requestPresentationStyle(.expanded)
        
        let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC(withSelectionImageData: gifData)
        lineBoxInput.delegate = self
        self.present(lineBoxInput, animated: true)
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource
extension TenorPickerVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.searchRepository.searchResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TenorCollectionViewCell", for: indexPath) as! TenorCollectionViewCell
        cell.setup(searchRepository.searchResults[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if self.searchRepository.shouldLoadNextPage(indexPath.item) {
            self.searchRepository.loadNextPage { _ in
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return !MessagesViewController.shared.isTransitioning
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if let urlStr = self.searchRepository.searchResults[indexPath.item].gifURL, let url = URL(string: urlStr) {
            // Tenor API requirement: register a 'click' when a gif is selected and how user found the gif
            TenorAPI.registerShare(searchText: self.searchBar.text, gifId: self.searchRepository.searchResults[indexPath.item].id)

            self.loadingView.isHidden = false
            
            let imageRequest = ImageRequest(url: url)
            ImagePipeline.shared.loadData(with: imageRequest) { [unowned self] result in
                switch result {
                case .success(let loadedValue):
                    self.openCaptionBoxWithImageData(gifData: loadedValue.data)
                default:
                    self.show(alert: "DOWNLOAD_ERROR".localized)
                }
            }
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension TenorPickerVC: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let numberOfItemsInRow = CGFloat(LayoutSettings.itemsPerRow)
        var columnWidth = (self.collectionView.frame.size.width - collectionView.contentInset.left - collectionView.contentInset.right)
        
        if let layoutCV = collectionViewLayout as? UICollectionViewFlowLayout {
            columnWidth -= (layoutCV.minimumInteritemSpacing * (numberOfItemsInRow - 1))
        }
        
        columnWidth /= numberOfItemsInRow
        
        return CGSize(width: columnWidth, height: columnWidth)
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        self.collectionView.collectionViewLayout.invalidateLayout()
        
    }
}

// MARK: - SearchBar
extension TenorPickerVC: UISearchBarDelegate, UIScrollViewDelegate, UITextFieldDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        self.searchRepository.search(searchBar.text) { _ in
            DispatchQueue.main.async {
                self.collectionView.setContentOffset(.zero, animated: false)
                self.collectionView.reloadData()
            }
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.refresh()
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if MessagesViewController.shared.presentationStyle == .compact {
            self.becomeResponderAfterExpand = true
            MessagesViewController.shared.requestPresentationStyle(.expanded)
            return false
        } else {
            return true
        }
    }
}

// MARK: - MultiLineInputBoxDelegate
extension TenorPickerVC: MultiLineInputBoxDelegate {
    
    func add(text: String, toImageData imageData: Data) {
        self.loadingView.isHidden = false
        
        let captionGenerator: ImageCaptionGenerator = ImageCaptionGenerator()
        captionGenerator.delegate = self
        captionGenerator.generateCaption(text, toImageData: imageData)
    }
}

// MARK: - CaptionGeneratorDelegate
extension TenorPickerVC: CaptionGeneratorDelegate {
    
    func finishedCaptionedMedia(atPath captionedMediaPath: URL?, withError error: Error?) {
        self.loadingView.isHidden = true
        
        if let error = error {
            self.show(alert: error.localizedDescription)
        } else if let captionedMediaPath = captionedMediaPath {
            MessagesViewController.shared.composeMessage(with: captionedMediaPath)
        }
    }
}
