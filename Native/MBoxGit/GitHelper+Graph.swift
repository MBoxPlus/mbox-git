//
//  GitHelper+Graph.swift
//  MBoxGit
//
//  Created by 詹迟晶 on 2020/6/2.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

extension GitHelper {
    public func aheadBehind(currentBranch: String, otherBranch: String) throws -> (ahead: size_t, behind: size_t) {
        guard let b1 = self.branch(named: currentBranch) else {
            throw RuntimeError("Could not find the branch `\(currentBranch)`")
        }
        guard let b2 = self.branch(named: otherBranch) else {
            throw RuntimeError("Could not find the branch `\(otherBranch)`")
        }
        return try self.repo.aheadBehind(local: b1.oid, upstream: b2.oid).get()
    }

    public func aheadBehind(currentCommit: String, otherCommit: String) throws -> (ahead: size_t, behind: size_t) {
        guard let b1 = OID(string: currentCommit) else {
            throw RuntimeError("Could not find the commit `\(currentCommit)`")
        }
        guard let b2 = OID(string: otherCommit) else {
            throw RuntimeError("Could not find the commit `\(otherCommit)`")
        }
        return try self.repo.aheadBehind(local: b1, upstream: b2).get()
    }

    open func calculateLatestCommit(commits: [String]) throws -> String? {
        if commits.count == 0 {
            return nil
        }
        let uniqueCommitsDict = try commits.reduce(into: Dictionary<String, String>()) { (dict, commit) in
            if let oid = OID(string: commit) {
                let longOID = try self.repo.longOID(for: oid).get()
                dict[longOID.description] = commit
            }
        }
        if uniqueCommitsDict.count == 0 {
            return nil
        }

        var commitsStack = [uniqueCommitsDict.first!.value]
        for (index, commit) in uniqueCommitsDict.values.enumerated() {
            if index == 0 { continue }
            for (i, c) in commitsStack.enumerated() {
                guard let cOID = OID(string: c), let cLOID = try? self.repo.longOID(for: cOID).get() else {
                    throw RuntimeError("Could not find the commit `\(c)`")
                }
                guard let commitOID = OID(string: commit), let commitLOID = try? self.repo.longOID(for: commitOID).get() else {
                    throw RuntimeError("Could not find the commit `\(commit)`")
                }
                if (try self.repo.isDescendant(of: commitLOID, for: cLOID).get()) == true {
                    commitsStack.insert(commit, at: i)
                    break
                }
                if i == commitsStack.count - 1 {
                    if (try self.repo.isDescendant(of: cLOID, for: commitLOID).get()) == true {
                        commitsStack.append(commit)
                        break
                    } else {
                        return nil
                    }
                }
            }
        }
        if commitsStack.count == uniqueCommitsDict.count {
            return commitsStack.first
        }
        return nil
    }
}
