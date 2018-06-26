//
//  ProductTableViewController.swift
//  RetailVision
//
//  Created by Colby L Williams on 4/22/18.
//  Copyright © 2018 Colby L Williams. All rights reserved.
//

import Foundation
import UIKit
import Whisper


class ProductTableViewController : UITableViewController {

    @IBOutlet var addButton: UIBarButtonItem!
    @IBOutlet var activityButton: UIView!
    @IBOutlet weak var cameraButton: UIBarButtonItem!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    
    var activityButtonItem: UIBarButtonItem!
    
    var currencyFormatter: CurrencyFormatter { return ProductManager.shared.currencyFormatter }
    
    var products: [Product] { return ProductManager.shared.products }
    

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Products"

        activityButtonItem = UIBarButtonItem(customView: activityButton)
        
        if let refreshControl = refreshControl {
            refreshControl.tintColor = #colorLiteral(red: 1, green: 0.1764705882, blue: 0.3333333333, alpha: 1)
            tableView.contentOffset = CGPoint(x:0, y:-refreshControl.frame.size.height)
            refreshControl.beginRefreshing()
            refreshData()
        }
        
        navigationItem.setLeftBarButtonItems([cameraButton, refreshButton], animated: false)
        navigationItem.setRightBarButtonItems([addButton, editButtonItem], animated: false)
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        ProductManager.shared.clearSelectedProduct()
    }
    
    
    func refreshData() {
        ProductManager.shared.refresh {
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }
    }
    
    
    @IBAction func refreshControlValueChanged(_ sender: Any) {
        refreshData()
    }
    
    @IBAction func refreshModelButtonTouched(_ sender: Any) {
        navigationItem.setLeftBarButtonItems([cameraButton, activityButtonItem], animated: true)
        ProductManager.shared.trainAndDownloadCoreMLModel(withName: "kwjewelry", progressUpdate: self.displayUpdateMessage, self.displayFinalMessage)
    }
    
    func displayUpdateMessage(message: String) {
        displayMessage(message: message)
    }

    func displayFinalMessage(success: Bool, message: String) {
        displayMessage(message: message, thenHide: true)
    }

    func displayMessage(message: String, thenHide: Bool = false) {
        
        guard let navController = navigationController else { return }

        DispatchQueue.main.async {
            Whisper.show(whisper: Message(title: message, backgroundColor: #colorLiteral(red: 1, green: 0.1764705882, blue: 0.3333333333, alpha: 1)), to: navController, action: .present)
            if thenHide {
                Whisper.hide(whisperFrom: navController, after: 4)
                self.navigationItem.setLeftBarButtonItems([self.cameraButton, self.refreshButton], animated: true)
            }
        }
    }
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return products.count }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "productCell", for: indexPath)
        
        let product = products[indexPath.row]
        
        cell.textLabel?.text = product.name ?? product.id
        cell.detailTextLabel?.text = currencyFormatter.string(from: NSNumber(value: product.price ?? 0))
        
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction.init(style: .destructive, title: "Delete") { (action, view, callback) in
            self.deleteResource(at: indexPath, from: tableView, callback: callback)
        }
        return UISwipeActionsConfiguration(actions: [ action ] );
    }
    
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteResource(at: indexPath, from: tableView)
        }
    }
    
    
    func deleteResource(at indexPath: IndexPath, from tableView: UITableView, callback: ((Bool) -> Void)? = nil) {
        ProductManager.shared.delete(productAt: indexPath.row) { success in
            if success {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            callback?(success)
        }
    }
    
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let cell = sender as? UITableViewCell, let index = tableView.indexPath(for: cell) {
            ProductManager.shared.selectedProduct = products[index.row]
        }
    }
}


