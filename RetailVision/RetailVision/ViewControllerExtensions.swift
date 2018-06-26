//
//  ViewControllerExtensions.swift
//  RetailVision
//
//  Created by Colby L Williams on 4/12/18.
//  Copyright © 2018 Colby L Williams. All rights reserved.
//

import Foundation
import UIKit
#if canImport(AzureData)
import AzureData
#endif

extension UIViewController {
    
    func showErrorAlert (_ error: Error) {
        
        var title = "Error"
        var message = error.localizedDescription
        
        #if canImport(AzureData)
        if let documentError = error as? DocumentClientError {
            title += ": \(documentError.kind)"
            message = documentError.message
        }
        #endif
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction.init(title: "Dismiss", style: .cancel, handler: nil))
        self.present(alertController, animated: true) { }
    }
}
