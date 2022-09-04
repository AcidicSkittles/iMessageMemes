//
//  MultiLineInputBoxVC.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 8/31/22.
//

import UIKit
import SnapKit

public protocol MultiLineInputBoxDelegate: AnyObject {
    func addText(text: String, toImageData imageData: Data)
    func addText(text: String, toVideoAtPath videoPath: URL)
}

class MultiLineInputBoxVC: UIViewController {

    var delegate: MultiLineInputBoxDelegate?
    var selectionImageData: Data?
    var selectionVideoPath: URL?
    private var textView: UITextView!
    private var submitButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .white
        
        let navBar = UINavigationBar(frame: .zero)
        let navigationItem = UINavigationItem(title: "Add Top Caption")
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
        self.submitButton.setTitle("Add Caption!", for: .normal)
        
        self.submitButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        self.textView = UITextView(frame: self.view.bounds)
        self.textView.font = UIFont(name: CaptionGenerator.defaultMemeFontName(), size: 16)
        self.textView.autocapitalizationType = .sentences
        self.textView.autocorrectionType = .yes
        self.textView.inputAccessoryView = self.submitButton
        
        self.view.addSubview(self.textView)
        
        self.textView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(navBar.snp.bottom)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.textView.becomeFirstResponder()
    }
    
    @objc func submitPressed() {
        
        if self.selectionImageData != nil {
            self.delegate?.addText(text: self.textView.text ?? "", toImageData: self.selectionImageData!)
        } else if self.selectionVideoPath != nil {
            self.delegate?.addText(text: self.textView.text ?? "", toVideoAtPath: self.selectionVideoPath!)
        }
        
        self.close()
    }
    
    @objc func close() {
        self.dismiss(animated: true)
    }
}
