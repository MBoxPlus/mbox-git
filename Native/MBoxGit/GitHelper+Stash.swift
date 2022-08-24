//
//  GitHelper+Stash.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/7/2.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2
import Then

public struct Stash {
    public var id: Int
    public var message: String
    public var commit: String
    init(id: Int, message: String, oid: OID) {
        self.id = id
        self.message = message
        self.commit = oid.description
    }
    init(_ stash: SwiftGit2.Stash) {
        self.init(id: stash.id, message: stash.message, oid: stash.oid)
    }
}

extension GitHelper {
    public func findStash(_ name: String) -> (Int, String)? {
        return UI.log(
            verbose: "Search stash with name `\(name)`",
            resultOutput: { stashInfo -> String in
                if let (stashId, stashName) = stashInfo {
                    return "Found stash \(stashId) `\(stashName)`"
                } else {
                    return "Could not find any match stash."
                }},
            block: {
                var stashId: Int? = nil
                var stashMsg: String? = nil
                repo.forEachStash { stash -> Bool in
                    let stashName = stash.message.replacingOccurrences(of: "On (.+?): (.*)", with: "$2", options: .regularExpression)
                    if stashName == name {
                        stashId = stash.id
                        stashMsg = stash.message
                        return false
                    }
                    return true
                }
                if let stashId = stashId, let stashMsg = stashMsg {
                    return (stashId, stashMsg)
                }
                return nil})
    }

    @discardableResult
    public func save(stash name: String, untracked: Bool = false) throws -> Stash? {
        var options: StatusOptions = .excludeSubmodules
        options.insert(.includeUntracked)
        let status = self.status(options: options)
        if status.count == 0 {
            UI.log(verbose: "There is not changes, skip stash.")
            return nil
        }
        if status.first(where: { $0.status == Diff.Status.conflicted }) != nil {
            throw RuntimeError("Could not stash when there are conflict files. You should deal with the conflicts first.")
        }
        return try UI.log(verbose: "Stash changes (`\(name)`, untracked: \(untracked))", resultOutput: {
            if let stash = $0 {
                return "The Saved Stash: \(stash)."
            } else {
                return "Stash nothing."
            }
        }) {
            do {
                return try Stash(repo.save(stash: name, includeUntracked: untracked).get())
            } catch {
                if (error as NSError).code == -3 /*GIT_ENOTFOUND*/ {
                    return nil
                }
                throw error
            }
        }
    }

    @discardableResult
    public func apply(stash name: String, drop: Bool = false) throws -> String? {
        guard let (stashId, stashMsg) = findStash(name) else {
            return nil
        }
        // Force reload libgit2 status
        _ = self.status()
        var error: NSError? = nil
        let retryCode = [-22, -13] // GIT_EUNCOMMITTED, GIT_ECONFLICT
        if drop {
            UI.log(verbose: "Pop stash id `\(stashId)` with `--index` mode.") {
                error = repo.pop(stash: stashId, index: true).error
                if let err = error,
                   retryCode.contains(err.code) {
                    UI.log(verbose: "Pop stash id `\(stashId)` failed, retry with `--no-index` mode.") {
                        error = repo.pop(stash: stashId).error
                    }
                }
            }
        } else {
            UI.log(verbose: "Apply stash id `\(stashId)` with `--index` mode.") {
                error = repo.apply(stash: stashId, index: true).error
                if let err = error,
                   retryCode.contains(err.code) {
                    UI.log(verbose: "Apply stash id `\(stashId)` failed, retry with `--no-index` mode.") {
                        error = repo.apply(stash: stashId).error
                    }
                }
            }
        }
        if let error = error {
            throw error
        }
        _ = self.status()
        return stashMsg
    }

    public func delete(stash name: String) throws {
        try UI.log(verbose: "Try to drop stash `\(name)`") {
            guard let (stashId, _) = findStash(name) else {
                return
            }
            try UI.log(verbose: "Drop stash id `\(stashId)`") {
                try repo.drop(stash: stashId).get()
            }
        }
    }

}
