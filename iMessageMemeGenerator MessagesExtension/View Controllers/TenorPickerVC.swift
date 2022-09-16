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
    weak public var tenorUrlDelegate: TenorUrlDelegate?
    var loadingView: LoadingView = UIView.fromNib()
    var becomeResponderAfterExpand: Bool = false
    let searchController = TenorSearchResultsController()
    var searchText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        ImagePipeline.Configuration.isAnimatedImageDataEnabled = true
        
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
        
        self.loadingView.frame = self.view.bounds
        self.loadingView.isHidden = true
        self.view.addSubview(self.loadingView)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didTransition),
            name: MessagesViewController.didTransitionKey,
            object: nil
        )
        
        self.setupLoadingView()
    }
    
    @objc func didTransition() {
        if self.becomeResponderAfterExpand {
            self.becomeResponderAfterExpand = false
            self.searchBar.becomeFirstResponder()
        }
    }
    
    @objc func refresh() {
        self.searchController.search(searchText) { _ in
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    func openCaptionBoxWithImageData(gifData: Data) {
        self.searchBar.resignFirstResponder()
        
        let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC(withSelectionImageData: gifData)
        lineBoxInput.delegate = self
        
        MessagesViewController.shared.requestPresentationStyle(.expanded)
        
        self.present(lineBoxInput, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension TenorPickerVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.searchController.searchResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TenorCollectionViewCell", for: indexPath) as! TenorCollectionViewCell
        cell.setup(searchController.searchResults[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if self.searchController.shouldLoadNextPage(indexPath.item) {
            self.searchController.loadNextPage { _ in
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
        
        if let urlStr = self.searchController.searchResults[indexPath.item].gifURL, let url = URL(string: urlStr) {
            
            TenorAPI.registerShare(searchText: self.searchBar.text, gifId: self.searchController.searchResults[indexPath.item].id)

            self.loadingView.isHidden = false
            
            let imageRequest = ImageRequest(url: url)
            ImagePipeline.shared.loadData(with: imageRequest) { [unowned self] result in
                self.loadingView.isHidden = true
                
                switch result {
                case .success(let loadedValue):
                    self.openCaptionBoxWithImageData(gifData: loadedValue.data)
                default:
                    self.show(alert: "Unable to download gif")
                }
            }
        }
    }
}

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

extension TenorPickerVC: UISearchBarDelegate, UIScrollViewDelegate, UITextFieldDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchText = searchBar.text ?? ""
        searchBar.resignFirstResponder()
        self.searchController.search(searchText) { _ in
            DispatchQueue.main.async {
                self.collectionView.setContentOffset(.zero, animated: false)
                self.collectionView.reloadData()
            }
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchText = searchBar.text ?? ""
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

extension TenorPickerVC: MultiLineInputBoxDelegate {
    
    func add(text: String, toImageData imageData: Data) {
        self.loadingView.isHidden = false
        
        let captionGenerator: ImageCaptionGenerator = ImageCaptionGenerator()
        captionGenerator.delegate = self
        captionGenerator.generateCaption(text, toImageData: imageData)
    }
}

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
