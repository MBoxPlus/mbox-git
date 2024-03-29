//
//  GitHelper+Branch.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/7/2.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2
import Then

public extension GitHelper {
    var localBranches: [String] {
        return UI.log(verbose: "List local branches:", resultOutput: { $0.joined(separator: "\n") }) {
            return (try? repo.localBranches().get().map { $0.name }) ?? []
        }
    }

    /// Load and return a list of all local branches which contains name.
    func localBranches(contains name: String) throws -> [String] {
        return try UI.log(verbose: "List local branches which contains `\(name)`:", resultOutput: { $0.joined(separator: "\n") }) {
            let oid = (try repo.object(from: name).get()).oid
            let branches = try repo.localBranches().get()
            return branches.filter { (try? repo.isDescendant(of: oid, for: $0.oid).get()) == true }.map { $0.name }
        }
    }

    var remoteBranches: [String] {
        return UI.log(verbose: "List remote branches:", resultOutput: { "Found \($0.count) branch\($0.count > 1 ? "es" : "")" }) {
            return (try? repo.remoteBranches().get().map { $0.name }) ?? []
        }
    }

    func remoteBranch(named name: String) -> Branch? {
        return UI.log(verbose: "Find remote branch `\(name)`:", resultOutput: { $0?.longName ?? "(none)" }) {
            guard let remotes = try? self.remotes() else { return nil }
            for remote in remotes {
                if let branch = self.branch(named: "\(remote)/\(name)") {
                    return branch
                }
            }
            return nil
        }
    }

    func localBranch(named name: String) -> Branch? {
        return UI.log(verbose: "Find local branch `\(name)`:", resultOutput: { $0?.longName ?? "(none)" }) {
            return try? repo.localBranch(named: name).get()
        }
    }

    func branch(named name: String) -> Branch? {
        return UI.log(verbose: "Find branch `\(name)`:", resultOutput: { $0?.longName ?? "(none)" }) {
            return try? repo.branch(named: name).get()
        }
    }

    /// Load and return a list of all remote branches which contains name.
    func remoteBranches(contains name: String) throws -> [String] {
        return try UI.log(verbose: "List remote branches which contains `\(name)`:", resultOutput: { $0.joined(separator: "\n") }) {
            let oid = (try repo.object(from: name).get()).oid
            let branches = try repo.remoteBranches().get()
            return branches.filter { (try? repo.isDescendant(of: oid, for: $0.oid).get()) == true }.map { $0.name }
        }
    }

    func delete(branch: String) throws {
        try UI.log(verbose: "Delete branch `\(branch)`") {
            try repo.deleteBranch(branch).get()
        }
    }

    func setHEAD(_ head: GitPointer) throws {
        try UI.log(verbose: "Change HEAD to \(head)") {
            if head.isCommit {
                try repo.setHEAD(OID(string: head.value)!).get()
            } else {
                try repo.setHEAD(head.value).get()
            }
        }
    }

    func checkout(_ targetPointer: GitPointer,
                  basePointer: GitPointer? = nil,
                  create: Bool = false,
                  force: Bool = false) throws {
        try UI.log(verbose: "Checkout the \(create ? "new " : "")\(targetPointer):") {
            let curPointer = try currentDescribe()
            if targetPointer == curPointer {
                UI.log(verbose: "Current status is the \(targetPointer), skip checkout.")
                return
            }
            if create && targetPointer.isBranch {
                // Create a new branch
                if let basePointer = basePointer, basePointer != targetPointer {
                    try UI.log(verbose: "Create the new \(targetPointer) based on \(basePointer)") {
                        switch basePointer {
                        case .branch(let baseBranch):
                            _ = try self.repo.createBranch(targetPointer.value, baseBranch: baseBranch).get()
                        case .tag(let baseTag):
                            _ = try self.repo.createBranch(targetPointer.value, baseTag: baseTag).get()
                        case .commit(let baseCommit):
                            _ = try self.repo.createBranch(targetPointer.value, baseCommit: baseCommit).get()
                        default:
                            throw RuntimeError("Could not create a branch based \(basePointer)")
                        }
                    }
                } else if try self.repo.headIsUnborn().get() {
                    UI.log(verbose: "HEAD is in a unborn \(curPointer), will not create branch based it.")
                } else {
                    try UI.log(verbose: "Create the new \(targetPointer) based on current \(curPointer)") {
                        _ = try self.repo.createBranch(targetPointer.value).get()
                    }
                }
            }
            try UI.log(verbose: "Checkout to \(targetPointer) from \(curPointer)\(force ? " (Force)" : "")") {
                if GitHelper.useLibgit2 {
                    if targetPointer.isCommit {
                        try repo.checkout(OID(string: targetPointer.value)!, CheckoutOptions(strategy: .Force)).get()
                    } else if try self.repo.headIsUnborn().get() {
                        try repo.setHEAD(targetPointer.value.longBranchRef).get()
                    } else {
                        guard let targetRef: ReferenceType = reference(named: targetPointer.value) else {
                            throw RuntimeError("Could not find the \(targetPointer)")
                        }
                        try repo.checkout(targetRef.longName, CheckoutOptions(strategy: .Force)).get()
                    }
                } else {
                    var args = ["checkout"]
                    if try self.repo.headIsUnborn().get() {
                        args << "-b"
                    }
                    if force {
                        args << "-f"
                    }
                    args << targetPointer.value
                    try self.execGit(args)
                }
            }
        }
    }

    func createBranch(_ name: String, base: GitPointer? = nil) throws {
        try UI.log(verbose: "Create the branch `\(name)` (base \(base?.description ?? "HEAD"))") {
            if let base = base {
                if base.isBranch {
                    _ = try repo.createBranch(name, baseBranch: base.value).get()
                } else if base.isTag {
                    _ = try repo.createBranch(name, baseTag: base.value).get()
                } else if base.isCommit {
                    _ = try repo.createBranch(name, baseCommit: base.value).get()
                } else {
                    throw RuntimeError("No support base \(base)")
                }
            } else {
                _ = try repo.createBranch(name).get()
            }
        }
    }

    func reference(named: String) -> (local: Bool, ref: GitPointer)? {
        if let targetRef = self.reference(named: named, onlyLocal: false) {
            if let branch = targetRef as? Branch {
                return (local: !branch.isRemote, ref: .branch(branch.shortName!))
            }
            return (local: true, ref: GitPointer(targetRef))
        }
        if let object = try? repo.object(from: named).get() as? Commit {
            return (local: true, ref: .commit(object.oid.description))
        }
        return nil
    }

    func reference(named: String, onlyLocal: Bool = false) -> ReferenceType? {
        if let targetRef = try? repo.reference(named: named).get() {
            return targetRef
        }
        if !onlyLocal, let remotes = try? self.remotes(), !remotes.isEmpty {
            for remote in remotes {
                if let targetRef = try? repo.reference(named: "\(remote)/\(named)").get() {
                    return targetRef
                }
            }
        }
        return nil
    }

    func trackBranch(_ local: String? = nil, autoMatch: Bool = true) -> String? {
        let msg: String
        if let name = local {
            msg = "Get track branch for branch `\(name)`:"
        } else {
            msg = "Get current track branch:"
        }
        return UI.log(
            verbose: msg,
            resultOutput: {
                if let result = $0 {
                    return "The track branch is `\(result)`."
                } else {
                    return "Could not get the track branch."
                }},
            block: { () -> String? in
                guard let local = local ?? self.currentBranch else {
                    return nil
                }
                if let branch = try? repo.trackBranch(local: local).get().name { return branch }
                if !autoMatch { return nil }
                if let branch = self.remoteBranch(named: local)?.name {
                    self.setTrackBranch(local: local, remote: branch)
                    return branch
                }
                return nil
        })
    }

    @discardableResult
    func setTrackBranch(local: String, remote: String?) -> Bool {
        let message = remote == nil ? "Unset branch `\(local)`'s track branch" : "Set branch `\(local)`'s track branch `\(remote!)`"
        return UI.log(verbose: message, resultOutput: {
            return "Set the track branch \($0 ? "success" : "fail")."
        }) {
            repo.setTrackBranch(local: local, remote: remote).isSuccess
        }
    }
}
