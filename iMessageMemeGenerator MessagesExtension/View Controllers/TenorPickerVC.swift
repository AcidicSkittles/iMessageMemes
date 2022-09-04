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
    let captionGenerator: CaptionGenerator = CaptionGenerator()
    var becomeResponderAfterExpand: Bool = false
    let searchController = TenorSearchResultsController()
    var searchText = ""
    let spacing = CGFloat(2)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        ImagePipeline.Configuration.isAnimatedImageDataEnabled = true
        
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.refresh()
        
        self.searchBar.delegate = self
        self.searchBar.searchTextField.delegate = self
        
        self.collectionView.contentInset = UIEdgeInsets.init(top: self.spacing, left: self.spacing, bottom: self.spacing, right: self.spacing)
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumLineSpacing = self.spacing
            layout.minimumInteritemSpacing = self.spacing
        }
        
        self.loadingView.frame = self.view.bounds
        self.loadingView.isHidden = true
        self.view.addSubview(self.loadingView)
        
        self.captionGenerator.delegate = self
        
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
        
        let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC()
        lineBoxInput.delegate = self
        lineBoxInput.selectionImageData = gifData
        
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
        
        let numberOfItemsInRow = CGFloat(UIView.itemsPerRow())
        
        var columnWidth = (self.collectionView.frame.size.width - collectionView.contentInset.left - collectionView.contentInset.right)
        
        if let layoutCV = collectionViewLayout as? UICollectionViewFlowLayout {
            columnWidth -= (layoutCV.minimumInteritemSpacing * (numberOfItemsInRow - 1))
        }
        
        columnWidth /= numberOfItemsInRow
        
        let height = 150.0 / 200.0 * columnWidth
        return CGSize(width: columnWidth, height: height)
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
    
    func addText(text: String, toImageData imageData: Data) {
        self.loadingView.isHidden = false
        
        self.captionGenerator.generateCaption(text, toImageData: imageData)
    }
    
    func addText(text: String, toVideoAtPath videoPath: URL) {
        self.loadingView.isHidden = false
        
        self.captionGenerator.generateCaption(text, toVideoAtPath: videoPath)
    }
}

extension TenorPickerVC: CaptionGeneratorDelegate {
    
    func finishedCaptionedImagePath(_ captionedImagePath: URL) {
        self.loadingView.isHidden = true
        MessagesViewController.shared.composeMessage(with: captionedImagePath)
    }
    
    func finishedCaptionedVideoPath(_ captionedVideoPath: URL) {
        self.loadingView.isHidden = true
        MessagesViewController.shared.composeMessage(with: captionedVideoPath)
    }
}
