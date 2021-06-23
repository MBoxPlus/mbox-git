//
//  GitHelper+Clean.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/8/13.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

extension GitHelper {
    public var isClean: Bool {
        return UI.log(verbose: "Check git is clean",
                      resultOutput: { $0 ? "It is clean." : "It is NOT clean." },
                      block: {
                        status().count == 0})
    }

    public func clean(includeDirectory: Bool = true, includeIgnore: Bool = false) throws {
        var options = CleanOptions()
        if includeDirectory {
            options.update(with: .directory)
        }
        if includeIgnore {
            options.update(with: .includeIgnored)
        }
        try UI.log(verbose: "Clean git repository") {
            try repo.clean(options, shouldRemove: { path in
                UI.log(verbose: "Removing \(path)")
                return true
            }).get()
        }
    }

    public func checkout() throws {
        try UI.log(verbose: "Checkout all changes") {
            try repo.checkout(CheckoutOptions(strategy: .Force)).get()
        }
    }
}
