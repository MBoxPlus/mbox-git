//
//  GitHelper+Worktree.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/7/2.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

extension GitHelper {
    public var isWorkTree: Bool {
        return repo.isWorkTree
    }

    @discardableResult
    public func pruneWorkTree(_ name: String, force: Bool = false) throws -> String? {
        return try UI.log(verbose: "Prune worktree `\(name)`") {
            if let path = try repo.pruneWorkTree(name, force: force).get() {
                UI.log(verbose: path)
                return path
            } else {
                UI.log(verbose: "There is nothing to prune.")
                return nil
            }
        }
    }

    public func cleanWorkTrees() throws {
        try UI.log(verbose: "Clean worktrees") {
            guard let path = try? repo.path(for: .worktrees).get().path,
                  path.isExists else {
                UI.log(verbose: "No worktree directory.")
                return
            }
            try UI.log(verbose: "Deleting worktrees path: \(path)") {
                try FileManager.default.removeItem(atPath: path)
            }
        }
    }

    public func addWorkTree(name: String, path: String, head: String? = nil) throws {
        var message = "Add worktree `\(name)` at `\(path)`"
        if let head = head {
            message.append(" (based \(head))")
        }
        try UI.log(verbose: message) {
            try repo.addWorkTree(name: name, path: path, head: head).get()
        }
    }
}
