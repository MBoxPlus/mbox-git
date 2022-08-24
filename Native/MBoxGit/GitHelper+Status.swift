//
//  GitHelper+Status.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/7/2.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2
import Then

extension Diff.Status {
    static let index = Diff.Status(rawValue: 0b111111)
    static let workTree = Diff.Status(rawValue: 0b111111 << 7)

    static let indexAllModified = Diff.Status.indexModified.union(.indexRenamed).union(.indexTypeChange)
    static let workTreeAllModified = Diff.Status.workTreeModified.union(.workTreeRenamed).union(.workTreeTypeChange)
    static let modified = Diff.Status.indexAllModified.union(.workTreeAllModified)
    static let deleted = Diff.Status.indexDeleted.union(.workTreeDeleted)
    static let new = Diff.Status.indexNew.union(.workTreeNew)

    public var type: Diff.Status {
        if rawValue & Diff.Status.new.rawValue > 0 {
            return .new
        } else if rawValue & Diff.Status.modified.rawValue > 0 {
            return .modified
        } else if rawValue & Diff.Status.deleted.rawValue > 0 {
            return .deleted
        } else {
            return self
        }
    }

    public var typeName: String {
        switch type {
        case .modified:
            return "modified"
        case .new:
            return "new file"
        case .deleted:
            return "deleted"
        case .ignored:
            return "ignored"
        case .conflicted:
            return "conflicted"
        default:
            return "unknown"
        }
    }
}

extension GitHelper {
    public var isUnborn: Bool {
        return (try? repo.headIsUnborn().get()) ?? false
    }

    public func HEAD() throws -> ReferenceType {
        let head = try repo.HEAD().get()
        UI.log(verbose: "Git head: \(head.longName) (\(head.oid))")
        return head
    }

    public var currentBranch: String? {
        if isUnborn, let head = try? repo.unbornHEAD().get() {
            return head.name
        }
        return try? HEAD().shortName
    }

    public var currentCommit: String? {
        return try? HEAD().oid.description
    }

    public var currentTag: String? {
        guard let oid = try? HEAD().oid else { return nil }
        return UI.log(verbose: "Get Tag for \(oid)") {
            return try? repo.tag(oid).get().name
        }
    }

    public func currentDescribe() throws -> GitPointer {
        return try UI.log(verbose: "Get current git status:",
                          resultOutput: { "The git is in \($0)" },
                          block: {
                            if try repo.headIsUnborn().get() {
                                let head = try repo.unbornHEAD().get()
                                return .branch(head.name)
                            }
                            let reference: ReferenceType = try HEAD()
                            if let branchRef = reference as? Branch, let branch = branchRef.shortName {
                                return .branch(branch)
                            }
                            if let tagRef = reference as? TagReference {
                                return .tag(tagRef.name)
                            }
                            // lightweight Tag
                            if let tag = try? repo.allTags().get().first(where: { $0.oid == reference.oid }) {
                                return .tag(tag.name)
                            }
                            return .commit(reference.oid.description)
        })
    }

    public func status(options: StatusOptions? = nil) -> [StatusEntry] {
        return UI.log(verbose: "Get git status", resultOutput: {
            var stages = [StatusEntry]()
            var unstages = [StatusEntry]()
            var conflicted = [StatusEntry]()
            for entry in $0 {
                let status = entry.status.rawValue
                if (status & Diff.Status.index.rawValue) > 0 {
                    stages << entry
                }
                if (status & Diff.Status.workTree.rawValue) > 0 {
                    unstages << entry
                }
                if (status & Diff.Status.conflicted.rawValue) > 0 {
                    conflicted << entry
                }
            }
            var desc = [String]()
            if stages.isEmpty {
                desc.append("Nothing to commit.")
            } else {
                stages.sort(by: { e1, e2 -> Bool in
                    let path1 = (e1.headToIndex?.newFile ?? e1.headToIndex?.oldFile)!.path
                    let path2 = (e2.headToIndex?.newFile ?? e2.headToIndex?.oldFile)!.path
                    return path1 < path2
                })
                desc.append("Changes to be commited: ")
                for entry in stages {
                    let typeName = (entry.status.typeName + ":").ljust(10)
                    desc.append("  \(typeName)   \((entry.headToIndex?.newFile ?? entry.headToIndex?.oldFile)!.path)".ANSI(.green))
                }
                desc.append("\(stages.count(where: { $0.status.type == .new } )) new, \(stages.count(where: { $0.status.type == .modified })) modified, \(stages.count(where: { $0.status.type == .deleted })) deleted\n")
            }
            if unstages.isEmpty {
                desc.append("Working tree clean.")
            } else {
                unstages.sort(by: { e1, e2 -> Bool in
                    let path1 = (e1.indexToWorkDir?.newFile ?? e1.indexToWorkDir?.oldFile)!.path
                    let path2 = (e2.indexToWorkDir?.newFile ?? e2.indexToWorkDir?.oldFile)!.path
                    return path1 < path2
                })
                desc.append("Changes is not staged: ")
                for entry in unstages {
                    let typeName = (entry.status.typeName + ":").ljust(10)
                    desc.append("  \(typeName)   \((entry.indexToWorkDir?.newFile ?? entry.indexToWorkDir?.oldFile)!.path)")
                }
                desc.append("\(unstages.count(where: { $0.status.type == .new } )) new, \(unstages.count(where: { $0.status.type == .modified })) modified, \(unstages.count(where: { $0.status.type == .deleted })) deleted\n")
            }
            if unstages.isEmpty && stages.isEmpty {
                desc = [desc.joined(separator: " ")]
            }
            if !conflicted.isEmpty {
                desc.append("\(conflicted.count) \(conflicted.count > 1 ? "files" : "file") have conflict:")
                for entry in conflicted {
                    desc.append("  \((entry.indexToWorkDir?.newFile ?? entry.indexToWorkDir?.oldFile)!.path)".ANSI(.red))
                }
            }
            return desc.joined(separator: "\n")
        }) {
            return (try? repo.status(options: options).get()) ?? []
        }
    }

    public var hasConflicts: Bool {
        return UI.log(verbose: "Check git has conflicts",
                      resultOutput: { $0 ? "There are some conflicts." : "There is not conflict." },
                      block: { return (try? repo.hasConflicts().get()) ?? false })
    }

    public func pointer(for name: String) -> GitPointer? {
        if let ref = repo.reference(named: name).value {
            if let ref = ref as? Branch {
                return .branch(ref.name)
            } else if let ref = ref as? TagReference {
                return .tag(ref.name)
            }
        } else if let obj = repo.object(from: name).value {
            if let ref = obj as? Commit {
                return .commit(ref.oid.description)
            } else if let ref = obj as? Tag {
                return .tag(ref.name)
            }
        }
        return nil
    }

    public func pointer(from gitPointer: GitPointer) -> GitPointer? {
        if let v = self.pointer(for: gitPointer.value) {
            if gitPointer.isUnknown {
                return v.clone(gitPointer.value)
            } else if v.type == gitPointer.type {
                return gitPointer
            } else {
                UI.log(verbose: "Found a \(v), but it is not a \(gitPointer.type).")
            }
        }
        return nil
    }

    public func pointer(for gitPointer: GitPointer, local: Bool = true, remote: Bool = true) -> GitPointer? {
        let fetchLocal = !gitPointer.isBranch || local
        if fetchLocal {
            let exist = UI.log(verbose: "Check \(gitPointer) exists", resultOutput: { "The \(gitPointer) \($0 != nil ? "exists" : "does not exist")."}) {
                return self.pointer(from: gitPointer)
            }
            if let exist = exist { return exist }
        }

        if remote, gitPointer.isBranch, let remotes = try? remotes(), !remotes.isEmpty {
            for remote in remotes {
                let remotePointer = gitPointer.clone("\(remote)/\(gitPointer.value)")
                let exist = UI.log(verbose: "Check \(remotePointer) exists", resultOutput: { "The \(remotePointer) \($0 != nil ? "exists" : "does not exist")."}) {
                    return self.pointer(from: remotePointer)
                }
                if let exist = exist { return exist }
            }
        }

        if (!fetchLocal) {
            let exist = UI.log(verbose: "Check \(gitPointer) exists", resultOutput: { "The \(gitPointer) \($0 != nil ? "exists" : "does not exist")."}) {
                return self.pointer(from: gitPointer)
            }
            if let exist = exist { return exist }
        }
        return nil
    }

    public func exists(gitPointer: GitPointer, local: Bool = true, remote: Bool = true) -> Bool {
        return pointer(for: gitPointer, local: local, remote: remote) != nil
    }

    public func commit(for gitPointer: GitPointer) throws -> String {
        return try UI.log(verbose: "Get commit for \(gitPointer)", resultOutput: { $0 }) {
            return try repo.object(from: gitPointer.value).get().oid.description
        }
    }

    public func commit() throws -> Commit {
        return try UI.log(verbose: "Get commit for HEAD", resultOutput: { $0.description }) {
            return try repo.commit().get()
        }
    }

    public func change(file: String, track: Bool) throws {
        let index = try repo.index().get()
        try index.entry(by: file, stage: false) { entry in
            if entry.skipWorktree == !track { return .success(false) }
            entry.skipWorktree = !track
            return .success(true)
        }.get()
    }
}
