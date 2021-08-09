//
//  GitHelper+Remote.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/7/2.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2
import Then

extension GitHelper {

    @discardableResult
    func execGit(_ args: [String], workingDirectory: String? = nil, showOutput: Bool = false) -> (cmd: GitCMD, status: Bool) {
        let cmd = GitCMD()
        cmd.workingDirectory = workingDirectory ?? self.path
        cmd.showOutput = showOutput
        let status: Bool = cmd.exec(args.joined(separator: " "))
        return (cmd: cmd, status: status)
    }

    public func remotes() throws -> [String] {
        return try UI.log(verbose: "List all remote", resultOutput: { $0.joined(separator: "\n") }) {
            try repo.allRemotes().get().map { $0.name }
        }
    }

    public class func lsRemote(at url: URL, showBranch: Bool, showTag: Bool) throws -> [String] {
        var message = "List all remote refs"
        if showBranch && showTag {
            message.append(" (Include Branch/Tag)")
        } else if showBranch {
            message.append(" (Only Branch)")
        } else if showTag {
            message.append(" (Only Tag)")
        }
        return try UI.log(verbose: message) {
            if GitHelper.useLibgit2 {
                return try Repository.lsRemote(at: url,
                                               showBranch: showBranch,
                                               showTag: showTag,
                                               callback: RemoteCallback(url: url.absoluteString, messageBlock: self.fetchVerbMessageCallback)).get()
            } else {
                var args = ["ls-remote", "--refs", "-q"]
                if showBranch {
                    args.append("--heads")
                }
                if showTag {
                    args.append("--tags")
                }
                args.append(url.absoluteString)
                let cmd = GitCMD()
                cmd.showColor = false
                cmd.showOutput = false
                if !cmd.exec(args.joined(separator: " ")) {
                    throw RuntimeError("Git failed: \(url)\n\(cmd.outputString)")
                }
                let lines: [Substring]
                if cmd.outputString.contains("\r\n") {
                    lines = cmd.outputString.split(separator: "\r\n")
                } else {
                    lines = cmd.outputString.split(separator: "\n")
                }
                return lines.compactMap { line in
                    var string = line
                    if line.hasSuffix("^{}") {
                        string = line.dropLast(3)
                    }
                    guard let name = string.split(separator: "\t").last else { return nil }
                    let arr = name.split(separator: "/")
                    if arr.count > 2 {
                        return arr[2...].joined(separator: "/")
                    } else {
                        return String(name)
                    }
                }
            }
        }
    }

    public func clone(checkout: Bool, recurseSubmodules: Bool = false) throws {
        guard let urlString = self.url else {
            throw RuntimeError("URL is empty.")
        }
        let message = "Clone from `\(urlString)`"
        try UI.log(info: message) {
            let tmpPath = FileManager.temporaryPath(scope: "MBoxGit")
            let tmpDir = tmpPath.deletingLastPathComponent
            let tmpName = tmpPath.lastPathComponent

            try? FileManager.default.removeItem(atPath: tmpPath)
            try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)

            do {
                if GitHelper.useLibgit2 {
                    guard let url = URL(string: urlString) else {
                        throw RuntimeError("URL `\(urlString)` is invalid.")
                    }
                    let fetchOptions = FetchOptions(url: urlString, tags: true, prune: false, messageBlock: type(of: self).fetchInfoMessageCallback)
                    let cloneOptions = CloneOptions(fetchOptions: fetchOptions, checkoutOptions: .init(strategy: .None))
                    _ = try Repository.clone(from: url,
                                             to: URL(fileURLWithPath: tmpPath),
                                             options: cloneOptions,
                                             recurseSubmodules: recurseSubmodules).get()
                } else {
                    var args = ["clone", "--progress", urlString, tmpName]
                    if !checkout {
                        args.append("--no-checkout")
                    }
                    if recurseSubmodules == true {
                        args.append("--recurse-submodules")
                    }
                    let result = execGit(args, workingDirectory: tmpDir, showOutput: true)
                    if !result.status {
                        throw RuntimeError("Clone Failed: `\(urlString)`\n\(result.cmd.outputString)")
                    }
                }
                try UI.log(verbose: "Move `\(tmpPath)` -> `\(self.path!)`") {
                    try? FileManager.default.createDirectory(atPath: self.path.deletingLastPathComponent, withIntermediateDirectories: true)
                    try FileManager.default.moveItem(atPath: tmpPath, toPath: self.path)
                }
                self.repo = try Repository.at(URL(fileURLWithPath: self.path)).get()
                if let commit = self.currentCommit {
                    try self.setHEAD(.commit(commit))
                }
            } catch {
                try? FileManager.default.removeItem(atPath: tmpPath)
                throw error
            }
        }
    }

    public func fetch() throws {
        try UI.log(verbose: "Fetch from remote (tags: true, prune: true)") {
            guard let url = self.url else {
                UI.log(verbose: "The git url is none.")
                return
            }
            if GitHelper.useLibgit2 {
                let opt = FetchOptions(url: url, tags: true, prune: true, messageBlock: type(of: self).fetchVerbMessageCallback)
                try repo.fetch(options: opt).get()
            } else {
                let result = execGit(["fetch", "--prune", "--tags", "--force", "--progress"])
                if !result.status {
                    throw RuntimeError("Fetch Failed: `\(url)`\n\(result.cmd.outputString)")
                }
                UI.log(verbose: "Check default branch exists") {
                    let info = execGit(["symbolic-ref", "refs/remotes/origin/HEAD"])
                    if info.status {
                        let defaultBranch = info.cmd.outputString
                        if execGit(["show-branch", defaultBranch]).status {
                            UI.log(verbose: "The default branch is `\(defaultBranch)`")
                        } else {
                            UI.log(verbose: "The default branch is missing (\(defaultBranch)).")
                            execGit(["remote", "set-head", "origin", "-a"])
                        }
                    } else {
                        UI.log(verbose: "The default branch is missing.")
                        execGit(["remote", "set-head", "origin", "-a"])
                    }
                }
            }
        }
    }

    public func pull() throws {
        try UI.log(verbose: "Pull from remote") {
            guard let remoteBranch = self.trackBranch() else {
                throw RuntimeError("No tracked branch to pull.")
            }
            if GitHelper.useLibgit2 {
                guard let url = self.url else {
                    throw RuntimeError("The git url is none.")
                }
                let opt = FetchOptions(url: url, tags: true, prune: true, messageBlock: type(of: self).fetchVerbMessageCallback)
                var v = remoteBranch.split(separator: "/")
                let remote = v.removeFirst()
                let branch = v.joined(separator: "/")
                try repo.pull(remote: String(remote), branch: branch, options: opt).get()
            } else {
                try fetch()
                try self.merge(with: .branch(remoteBranch))
            }
        }
    }

    public func push() throws {
        try UI.log(verbose: "Push branch to remote") {
            let pointer = try self.currentDescribe()
            if !pointer.isBranch {
                throw RuntimeError("Could not push the \(pointer)")
            }
            var remoteBranch = self.trackBranch()
            if let b = remoteBranch {
                if let index = b.range(of: "/")?.upperBound {
                    let shortname = b[index...]
                    remoteBranch = String(shortname)
                }
            } else {
                remoteBranch = pointer.value
            }
            try self.push(sourceRef: pointer.value, targetRef: remoteBranch!)
        }
    }

    public func push(ref: String, to remoteName: String? = nil) throws {
        try self.push(sourceRef: ref, targetRef: ref, to: remoteName)
    }

    private func remote(_ name: String?) throws -> Remote {
        let remotes = try repo.allRemotes().get()
        if remotes.count == 0 {
            throw RuntimeError("No remote in the repository.")
        }
        if let name = name {
            if let r = remotes.first(where: { $0.name.lowercased() == name.lowercased() } ) {
                return r
            }
            throw RuntimeError("No remote named `\(name)`.")
        } else {
            return remotes.first { $0.name == "origin" } ?? remotes.first!
        }
    }

    public func push(sourceRef: String, targetRef: String, to remoteName: String? = nil, force: Bool = false) throws {
        let remote = try self.remote(remoteName)
        let sourceRef = sourceRef.isEmpty ? sourceRef : (try repo.reference(named: sourceRef).get().longName)
        let targetRef = targetRef.isEmpty ? targetRef : (try repo.reference(named: targetRef).get().longName)
        guard let url = remote.pushURL ?? remote.URL else {
            throw RuntimeError("No url to push \(remote.name).")
        }
        try UI.log(verbose: "\(force ? "Force push" : "Push") `\(sourceRef):\(targetRef)` to \(remote.name): \(url)") {
            if GitHelper.useLibgit2 {
                let options = PushOptions(url: url, messageBlock: type(of: self).fetchVerbMessageCallback)
                try repo.push(remote.name, sourceRef: sourceRef, targetRef: targetRef, force: force, options: options).get()
            } else {
                var args = ["push", remote.name, "\(sourceRef):\(targetRef)"]
                if force {
                    args.append("--force")
                }
                let result = execGit(args)
                if !result.status {
                    throw RuntimeError("Push Failed: `\(sourceRef)`\n\(result.cmd.outputString)")
                }
            }
        }
    }
}
