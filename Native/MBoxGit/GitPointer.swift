//
//  GitPointer.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/7/2.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import SwiftGit2

/// A pointer to a git object.
public enum GitPointer: CustomStringConvertible, Equatable {
    case branch(String)
    case tag(String)
    case commit(String)
    case unknown(String)

    public var value: String {
        switch self {
        case let .commit(value):
            return value.count > 10 ? String(value[..<10]) : value
        case let .branch(value):
            return value
        case let .tag(value):
            return value
        case let .unknown(value):
            return value
        }
    }

    public var type: String {
        switch self {
        case .commit(_):
            return "commit"
        case .branch(_):
            return "branch"
        case .tag(_):
            return "tag"
        case .unknown(_):
            return "unknown type"
        }
    }

    public func clone(_ value: String) -> GitPointer {
        return GitPointer(type: self.type, value: value)!
    }

    public var isBranch: Bool {
        switch self {
        case .branch(_): return true
        default: return false
        }
    }

    public var isTag: Bool {
        switch self {
        case .tag(_): return true
        default: return false
        }
    }

    public var isCommit: Bool {
        switch self {
        case .commit(_): return true
        default: return false
        }
    }

    public var isUnknown: Bool {
        switch self {
        case .unknown(_): return true
        default: return false
        }
    }
    public var description: String {
        if isCommit {
            return "\(type) `\(value.count > 10 ? String(value[..<10]) : value)`"
        }
        return "\(type) `\(value)`"
    }

    public static func ==(lhs: GitPointer, rhs:GitPointer) -> Bool {
        switch (lhs,rhs) {
        case (.branch(let lBranch), .branch(let rBranch)):
            return lBranch == rBranch
        case (.tag(let lTag), .tag(let rTag)):
            return lTag == rTag
        case (.commit(let lCommit), .commit(let rCommit)):
            return lCommit == rCommit
        case (.unknown(let lvalue), _):
            return lvalue == rhs.value
        default:
            return false
        }
    }

    public init?(type: String, value: String) {
        switch type {
        case "branch":
            self = .branch(value)
        case "tag":
            self = .tag(value)
        case "commit":
            self = .commit(value)
        case "unknown type":
            self = .unknown(value)
        default:
            return nil
        }
    }

    internal init(_ reference: ReferenceType) {
        if let tag = reference as? TagReference {
            self = .tag(tag.name)
        } else if let branch = reference as? Branch {
            self = .branch(branch.name)
        } else {
            self = .commit(reference.oid.desc(length: 9))
        }
    }
}
