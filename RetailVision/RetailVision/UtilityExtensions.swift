//
//  UtilityExtensions.swift
//  RetailVision
//
//  Created by Colby L Williams on 4/27/18.
//  Copyright © 2018 Colby L Williams. All rights reserved.
//

import Foundation


extension String {
    func ensuringSuffix(_ suffix: String) -> String {
        if self.hasSuffix(suffix) {
            return self
        }
        return self + suffix
    }
    func removingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}

extension Bundle {
    func plistData(named name: String) -> Data? {
        if let url = self.url(forResource: name.removingSuffix(".plist"), withExtension: "plist") {
            return try? Data(contentsOf: url)
        }
        return nil
    }
    
    func plistDict(named name: String) -> [String:String]? {
        if let data = self.plistData(named: name) {
            let plistDecoder = PropertyListDecoder()
            return try? plistDecoder.decode([String:String].self, from: data)
        }
        return nil
    }
}
