//
//  ProductManager.swift
//  RetailVision
//
//  Created by Colby L Williams on 4/22/18.
//  Copyright © 2018 Colby L Williams. All rights reserved.
//

import Foundation
import UIKit
import AzureData
import AzureMobile
import CustomVision
import CoreML


enum ProductManagerError : Error {
    case noProductName
}

class ProductManager {
    
    static let shared: ProductManager = ProductManager()
    
    var visionClient: CustomVisionClient { return CustomVisionClient.shared }
    
    let currencyFormatter: CurrencyFormatter = {
        let formatter = CurrencyFormatter()
        formatter.locale = .current
        formatter.numberStyle = .currency
        return formatter
    }()
    
    
    var collection: DocumentCollection?
    
    var products: [Product] = []
    
    var tagIds: [String] = []
    
    var tagList: TagList? = nil {
        didSet {
            setTagIds()
        }
    }
    
    
    fileprivate
    var _selectedProduct: Product? {
        didSet {
            setTagIds()
        }
    }
    var selectedProduct: Product {
        get {
            if _selectedProduct == nil {
                _selectedProduct = Product()
            }
            return _selectedProduct!
        }
        set { _selectedProduct = newValue }
    }
    
    func clearSelectedProduct() {
        _selectedProduct = nil
    }
    
    func setTagIds() {
        if _selectedProduct == nil || _selectedProduct!.tags.isEmpty {
            tagIds = []
        } else {
            tagIds = _selectedProduct!.tags.compactMap { t in
                return tagList?.Tags?.first { $0.Name == t }?.Id
            }
        }
    }
    
    func getProduct(withName name: String) -> Product? {
        return products.first { $0.name == name }
    }
    
    func getModelUrl(fileManager: FileManager = FileManager.default, compiled: Bool = true) -> URL? {
        return visionClient.getModelUrl()
    }
    
    func trainAndDownloadCoreMLModel(withName name: String, progressUpdate update: @escaping (String) -> Void, _ completion: @escaping (Bool, String) -> Void) {
        return visionClient.trainAndDownloadCoreMLModel(withName: name, progressUpdate: update, completion)
    }
    
    
    
    func handleSaveResponse(_ response: Response<Product>, completion: @escaping () -> Void) {
        
        if let resource = response.resource {
            
            selectedProduct = resource
            
            if let i = products.index(of: selectedProduct) {
                products[i] = selectedProduct
            } else {
                products.append(selectedProduct)
            }
            
        } else if let clientError = response.clientError {
            print(clientError.message)
        } else if let error = response.error {
            print(error)
        }
        
        DispatchQueue.main.async { completion() }
    }
    
    func saveSelectedProduct() {
        saveSelectedProduct { print("finished") }
    }
    
    func saveSelectedProduct(_ completion: @escaping () -> Void) {
        
        if products.contains(selectedProduct) {
            assert(!selectedProduct.resourceId.isEmpty, "nope")
            
            collection?.replace(selectedProduct) { response in
                self.handleSaveResponse(response, completion: completion)
            }
        } else {
            assert(selectedProduct.resourceId.isEmpty, "nope")
            
            collection?.create(selectedProduct) { response in
                self.handleSaveResponse(response, completion: completion)
            }
        }
    }
    
    
    func refresh(_ completion: @escaping () -> Void) {
        
        guard AzureData.isConfigured() else { completion(); return }
        
        if collection == nil {
            refreshCollection {
                self.refreshProducts {
                    DispatchQueue.main.async { completion() }
                }
            }
        } else {
            refreshProducts {
                DispatchQueue.main.async { completion() }
            }
        }
        
        refreshTags()
    }
    
    
    func refreshCollection(_ completion: @escaping () -> Void) {
        
        AzureData.get(collectionWithId: Product.collectionId, inDatabase: Product.databaseId) { response in
            
            if let resource = response.resource {
                
                self.collection = resource
                
            } else if let clientError = response.clientError {
                print(clientError.message)
            } else if let error = response.error {
                print(error)
            }
            
            completion()
        }
    }
    
    func refreshProducts(_ completion: @escaping () -> Void) {
        
        self.collection?.get(documentsAs: Product.self) { response in
            
            if let resources = response.resource?.items {
                
                self.products = resources
                
            } else if let clientError = response.clientError {
                print(clientError.message)
            } else if let error = response.error {
                print(error)
            }
            
            completion()
        }
    }
    
    func delete(productAt index: Int, _ completion: (Bool) -> ()) {
        
        if (index < 0 || index >= products.count) {
            completion(false); return;
        }
        
        let product = products.remove(at: index)
        
        if product == selectedProduct {
            _selectedProduct = nil
        }
        
        completion(true)
        
        print("delete product")
        
        collection?.delete(product) { response in
            
            if response.result.isSuccess {
                print("deleted successfully")
            } else if let clientError = response.clientError {
                print(clientError.message)
            } else if let error = response.error {
                print(error.localizedDescription)
            }
        }
    }
    
    
    
    func refreshTags() {
        
        _refreshTags { _ in }
    }

    func _refreshTags(completion: @escaping  (CustomVisionResponse<TagList>) -> Void) {
        
        visionClient.getTags { r in
            
            if let tagList = r.resource {
                
                self.tagList = tagList
                
            } else if let e = r.error {
                print(e)
            }
            
            completion(r)
        }
    }

    
    func getImagesForSelectedProduct(_ completion: @escaping (CustomVisionResponse<[Image]>) -> Void) {
        if tagIds.isEmpty {
            completion(CustomVisionResponse([]))
        } else {
            return visionClient.getTaggedImages(withTags: tagIds, completion: completion)
        }
    }
    
    
    func addImagesForSelectedProduct(_ images: [UIImage], _ completion: @escaping (CustomVisionResponse<ImageCreateSummary>) -> Void) {
        
        guard let name = selectedProduct.name else { completion(CustomVisionResponse(ProductManagerError.noProductName)); return }
        
        if !tagIds.isEmpty {
            return visionClient.createImages(from: images, withTagIds: tagIds, completion: completion)
        } else {
            visionClient.createImages(from: images, withNewTagNamed: name) { r in
                self._refreshTags{ _ in
                    completion(r)
                }
            }
        }
    }
    
    
    let functionAppNameKey      = "AMFunctionAppName"
    let databaseAccountNameKey  = "AMDatabaseAccountName"
    
    let functionAppNameKeyDefault       = "AZURE_MOBILE_FUNCTION_APP_NAME"
    let databaseAccountNameKeyDefault   = "AZURE_MOBILE_COSMOS_DB_ACCOUNT_NAME"

    func configure() {
        
        visionClient.getKeysFrom(plistNamed: "RetailVision")
        
        let dict = Bundle.main.plistDict(named: "RetailVision")
        
        storeDatabaseAccount(functionName: dict?[functionAppNameKey], databaseName: dict?[databaseAccountNameKey], andConfigure: true)
    }
    
    
    func storeDatabaseAccount(functionName: String?, databaseName: String?, andConfigure configure: Bool = false) {
        
        print("storeDatabaseAccount functionName: \(functionName ?? "nil") databaseName: \(databaseName ?? "nil")")
        
        if let f = functionName, f != functionAppNameKeyDefault, let d = databaseName, d != databaseAccountNameKeyDefault, let baseUrl = URL(string: "https://\(f).azurewebsites.net") {
            if !AzureData.isConfigured() && configure { AzureData.configure(forAccountNamed: d, withPermissionProvider: DefaultPermissionProvider(withBaseUrl: baseUrl)) }
        } else {
            AzureData.reset()
        }
        
        showApiKeyAlert(UIApplication.shared)
    }
    
    
    func showApiKeyAlert(_ application: UIApplication) {
        
        if AzureData.isConfigured() {
            
            if let navController = application.keyWindow?.rootViewController as? UINavigationController, let productsController = navController.topViewController as? ProductTableViewController {
                productsController.refreshData()
            }
            
        } else {
            
            let alertController = UIAlertController(title: "Configure App", message: "Enter the Name of a Azure.Mobile function app and a Azure Cosmos DB account name. Or add the key in code in `applicationDidBecomeActive`", preferredStyle: .alert)
            
            alertController.addTextField() { textField in
                textField.placeholder = "Function App Name"
                textField.returnKeyType = .next
            }
            
            alertController.addTextField() { textField in
                textField.placeholder = "Database Name"
                textField.returnKeyType = .done
            }
            
            alertController.addAction(UIAlertAction(title: "Done", style: .default) { a in
                
                self.storeDatabaseAccount(functionName: alertController.textFields?.first?.text, databaseName: alertController.textFields?.last?.text, andConfigure: true)
            })
            
            application.keyWindow?.rootViewController?.present(alertController, animated: true) { }
        }
    }
}



