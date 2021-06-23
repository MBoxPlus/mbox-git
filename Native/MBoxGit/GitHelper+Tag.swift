//
//  GitHelper+Tag.swift
//  MBoxGit
//
//  Created by 詹迟晶 on 2019/11/17.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

extension GitHelper {
    public func tags() throws -> [String: String] {
        let tags = try self.repo.allTags().get().map { ($0.name, $0.oid.description) }
        return Dictionary(uniqueKeysWithValues: tags)
    }

    public func maxVersionTag() -> (name: String, oid: String)? {
        let v = try? self.tags().filter {
            $0.key.first?.isNumber == true || $0.key.hasPrefix("v")
        }.max { (tag1, tag2) -> Bool in
            let tag1 = tag1.key.deletePrefix("v")
            let tag2 = tag2.key.deletePrefix("v")
            return tag1.compare(tag2, options: .numeric) == .orderedAscending
            }
        if let v = v {
            return (name: v.key, oid: v.value)
        }
        return nil
    }

    public func createTag(named name: String, basePointer: GitPointer? = nil, force: Bool = false) throws {
        try UI.log(verbose: "Create a tag `\(name)` based on \(basePointer?.description ?? "HEAD") (force: \(force))") {
            let oid: OID
            if let basePointer = basePointer {
                if basePointer.isCommit {
                    oid = OID(string: basePointer.value)!
                } else {
                    oid = try repo.object(from: basePointer.value).get().oid
                }
            } else {
                oid = try HEAD().oid
            }
            try self.repo.createTag(named: name, oid: oid, force: force).get()
        }
    }

    public func tag(for commit: String) throws -> String {
        guard let o = OID(string: commit) else {
            throw RuntimeError("Invalid commit `\(commit)`")
        }
        let oid = try repo.longOID(for: o).get()
        return try repo.tag(oid).get().name
    }
}
