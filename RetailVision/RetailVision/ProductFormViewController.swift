//
//  ProductFormViewController.swift
//  RetailVision
//
//  Created by Colby L Williams on 4/22/18.
//  Copyright © 2018 Colby L Williams. All rights reserved.
//

import Foundation
import Eureka

class ProductFormViewController : FormViewController {
    
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet var imagesButton: UIBarButtonItem!
    
    var changed = false
    
    var product: Product { return ProductManager.shared.selectedProduct }
    
    var currencyFormatter: CurrencyFormatter { return ProductManager.shared.currencyFormatter }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let name        = Product.FormTag.name
        let tags        = Product.FormTag.tags
        let inventory   = Product.FormTag.inventory
        let price       = Product.FormTag.price
        let saveButton  = Product.FormTag.saveButton
        
        form
        +++ Section("Product")
        <<< TextRow (name.tag) { row in
                row.title = name.title
                row.placeholder = name.placeholder
                row.value = product.name
            }.onChange {
                self.changed = true
                self.product.name = $0.value
            }
        <<< DecimalRow(price.tag) { row in
                row.useFormatterDuringInput = true
                row.title = price.title
                row.placeholder = price.placeholder
                row.formatter = currencyFormatter
                row.value = product.price
            }.onChange {
                self.changed = true
                self.product.price = $0.value
            }
        <<< StepperRow(inventory.tag) { row in
                row.title = inventory.title
                row.value = product.inventory
            }.onChange {
                self.changed = true
                self.product.inventory = $0.value
            }
            
        if navigationController is ProductNavigationController {
            form
            +++ Section("Vision")
            <<< ButtonRow("images") { row in
                    row.title = "Images"
                    row.presentationMode = .segueName(segueName: "ImageCollectionViewController", onDismiss: nil)
                }
        }
        
        form
        +++ MultivaluedSection (multivaluedOptions: [.Insert, .Delete], header: tags.title, footer: "") { section in
                section.tag = tags.tag
                section.addButtonProvider = { _ in
                    return ButtonRow { row in
                        row.title = "Add Tag"
                    }.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .left
                    }
                }
                section.multivaluedRowToInsertAt = { _ in
                    return TagRow(UUID().uuidString) { row in
                        row.title = ""
                        row.placeholder = "tag"
                    }.onChange { _ in
                        self.changed = true
                    }
                }
                for tag in product.tags {
                    section
                    <<< TagRow (tag) { row in
                            row.title = ""
                            row.value = tag
                        }.onChange { _ in
                            self.changed = true
                        }
                }
            }
        
        if !(navigationController is ProductNavigationController) {

            form
            +++ ButtonRow(saveButton.tag) { row in
                    row.title = saveButton.title
                }.onCellSelection { _, _ in
                    self.saveAndDismiss()
                }

            navigationItem.leftBarButtonItem = cancelButton
            navigationItem.rightBarButtonItem = self.saveButton
        
        } else {
            title = product.name
        }
    }
    

    override func rowsHaveBeenAdded(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenAdded(rows, at: indexes)
        self.changed = true
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)
        self.changed = true
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if changed && (navigationController is ProductNavigationController) {
            updateProductTags()
            ProductManager.shared.saveSelectedProduct()
        }
    }
    
    
    @IBAction func saveButtonTouchUpInside(_ sender: Any) {
        saveAndDismiss()
    }
    
    
    @IBAction func cancelButtonTouchUpInside(_ sender: Any) {
        dismiss(animated: true) { }
    }
    
    
    func saveAndDismiss() {
        updateProductTags()
        ProductManager.shared.saveSelectedProduct(self.dismiss)
    }
    
    func dismiss() {
        if navigationController is ProductNavigationController {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true) { }
        }
    }
    
    
    func updateProductTags () {
        
        if let tagsSection = form.sectionBy(tag: Product.FormTag.tags.tag) as? MultivaluedSection {
            
            var tags = tagsSection.values().compactMap { $0 as? String }
            
            if let name = product.name, !tags.contains(name) {
                tags.append(name)
            }
            
            product.tags = tags
        }
    }
}


// MARK: - TagRow

class TagCell: _FieldCell<String>, CellType {
    
    required public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func setup() {
        super.setup()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .asciiCapable
    }
}

class _TagRow: FieldRow<TagCell> {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

final class TagRow: _TagRow, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}
