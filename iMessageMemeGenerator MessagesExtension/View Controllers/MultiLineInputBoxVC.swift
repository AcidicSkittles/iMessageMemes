//
//  MultiLineInputBoxVC.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 8/31/22.
//

import UIKit
import SnapKit

public protocol MultiLineInputBoxDelegate: AnyObject {
    func add(text: String, toImageData imageData: Data)
    func add(text: String, toVideoAtPath videoPath: URL)
}

extension MultiLineInputBoxDelegate {
    func add(text: String, toImageData imageData: Data) {}
    func add(text: String, toVideoAtPath videoPath: URL) {}
}

class MultiLineInputBoxVC: UIViewController {

    weak var delegate: MultiLineInputBoxDelegate?
    private var selectionImageData: Data?
    private var selectionVideoPath: URL?
    private var textView: UITextView!
    private var submitButton: UIButton!
    var maxInputTextLength: Int = 2048
    var memeFontName: String = ModernMemeLabelMaker.defaultMemeFont
    
    convenience public init(withSelectionImageData imageData: Data) {
        self.init()
        self.selectionImageData = imageData
    }
    
    convenience public init(withSelectionVideoPath videoPath: URL) {
        self.init()
        self.selectionVideoPath = videoPath
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.textView.becomeFirstResponder()
    }
}

// MARK: - UI & UI Actions
extension MultiLineInputBoxVC {
    private func configureUI() {
        self.view.backgroundColor = .white
        
        let navBar = UINavigationBar(frame: .zero)
        let navigationItem = UINavigationItem(title: "ADD_TOP_CAPTION".localized)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(close))
        navBar.setItems([navigationItem], animated: false)
        self.view.addSubview(navBar)
        
        navBar.snp.makeConstraints { make in
            make.left.top.right.equalToSuperview()
        }
        
        self.submitButton = UIButton(type: .system)
        self.submitButton.addTarget(self, action: #selector(submitPressed), for: .touchUpInside)
        self.submitButton.titleLabel?.textColor = .white
        self.submitButton.tintColor = .white
        self.submitButton.backgroundColor = UIColor(red: 0, green: 128.0/255.0, blue: 252.0/255.0, alpha: 1)
        self.submitButton.titleLabel?.textAlignment = .center
        self.submitButton.setTitle("ADD_CAPTION".localized, for: .normal)
        
        self.submitButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        self.textView = UITextView(frame: self.view.bounds)
        self.textView.font = UIFont(name: self.memeFontName, size: 16)
        self.textView.autocapitalizationType = .sentences
        self.textView.autocorrectionType = .yes
        self.textView.inputAccessoryView = self.submitButton
        
        self.view.addSubview(self.textView)
        
        self.textView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(navBar.snp.bottom)
        }
    }
    
    @objc func submitPressed() {
        
        guard self.textView.text.count < self.maxInputTextLength else {
            self.show(alert: "MAX_INPUT_ERROR".localized(self.maxInputTextLength, self.textView.text.count))
            return
        }
        
        if self.selectionImageData != nil {
            self.delegate?.add(text: self.textView.text ?? "", toImageData: self.selectionImageData!)
        } else if self.selectionVideoPath != nil {
            self.delegate?.add(text: self.textView.text ?? "", toVideoAtPath: self.selectionVideoPath!)
        }
        
        self.close()
    }
    
    @objc func close() {
        self.dismiss(animated: true)
    }
}
