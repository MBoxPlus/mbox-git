//
//  GitHelper+Merge.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/7/2.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

extension GitHelper {
    public enum MergeStatus: Int {
        case uptodate = 0
        case forward = 1
        case behind = 2
        case diverged = 3
    }

    public func checkMergeStatus(curBranch: String? = nil, target: GitPointer? = nil) throws -> MergeStatus {
        return try UI.log(verbose: "Check merge status between \(curBranch ?? "Current") and \(target?.description ?? "Upstream")", resultOutput: { "The merge status is \($0)."}) {
            let current: Branch
            if let curBranch = curBranch {
                current = try repo.branch(named: curBranch).get()
            } else {
                if let branch = try repo.HEAD().get() as? Branch {
                    current = branch
                } else {
                    throw RuntimeError("Current git is not in a branch.")
                }
            }
            let otherOID: OID
            if let target = target {
                switch target {
                case .branch(let branch):
                    otherOID = try repo.branch(named: branch).get().oid
                case .tag(let tag):
                    otherOID = try repo.tag(named: tag).get().oid
                case .commit(let commit):
                    otherOID = try repo.commit(OID(string: commit)!).get().oid
                default:
                    otherOID = try repo.reference(named: target.value).get().oid
                }
            } else {
                otherOID = try repo.trackBranch(local: current.longName).get().oid
            }
            let baseOID = try repo.mergeBase(between: current.oid, and: otherOID).get()
            if current.oid == baseOID {
                return otherOID == baseOID ? .uptodate : .behind
            } else {
                return otherOID == baseOID ? .forward : .diverged
            }
        }
    }

    public func merge(with gitPointer: GitPointer) throws {
        try UI.log(verbose: "Merge with \(gitPointer)") {
            let oid: OID
            if gitPointer.isCommit {
                guard let o = OID(string: gitPointer.value) else {
                    throw RuntimeError("Invalid \(gitPointer)")
                }
                oid = try repo.longOID(for: o).get()
            } else {
                let reference = try repo.reference(named: gitPointer.value).get()
                oid = reference.oid
            }
            let way = try repo.merge(with: oid, message: "Merge \(gitPointer) into \(self.currentBranch!)").get()
            switch (way) {
            case .normal:
                UI.log(verbose: "Do a normal merge.")
            case .fastForward:
                UI.log(verbose: "Do a fast forward merge.")
            default:
                UI.log(verbose: "There is nothing to merge.")
            }
        }
    }

    public func hasMergeConflict(with gitPointer: GitPointer) throws -> Bool {
        return try UI.log(verbose: "Check merge conflict with \(gitPointer)") {
            let reference = try repo.reference(named: gitPointer.value).get()
            return try repo.hasMergeConflict(with: reference.oid).get()
        }
    }
}
