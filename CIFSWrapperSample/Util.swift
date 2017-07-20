//
//  Util.swift
//  CIFSWrapperSample
//
//  Created by Atsushi Tanaka on 2015/11/18.
//

import Foundation
import UIKit

extension UIViewController {
    func presentOKAlert(title: String?, message: String?, preferredStyle: UIAlertControllerStyle, okTitle: String = "OK", okHandler: ((UIAlertAction) -> Void)? = nil) -> UIAlertController {
    
        let alert = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
        alert.addAction(UIAlertAction(title: okTitle, style: .Default, handler: okHandler))
        
        self.presentViewController(alert, animated: true, completion: nil)
        
        return alert
    }
}