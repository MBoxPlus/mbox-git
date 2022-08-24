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
                var args = ["--refs"]
                if showBranch {
                    args.append("--heads")
                }
                if showTag {
                    args.append("--tags")
                }
                let lines = try self.lsRemote(at: url, args: args, environment: nil)
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

    public class func remoteVersion(at url: URL) throws -> String? {
        try UI.log(verbose: "Fetch Remote Git Version", resultOutput: { "Server Git Version: \($0 ?? "unknown")" }, block: {
            let script = Self.bundle.path(forResource: "get_git_server_version", ofType: "sh")!
            let cmd = MBCMD(workingDirectory: script.deletingLastPathComponent)
            cmd.bin = "sh"
            if cmd.exec("\(script.lastPathComponent) \(url)") != 0 {
                throw RuntimeError("Fetch Server Version Error: \(cmd.errorString)")
            }
            let line = cmd.outputString.trimmed
            guard let result = line.split(separator: "/").last else { return nil }
            return String(result)
        })
    }

    public static var gitVersion: String?
    public class func localVersion() -> String? {
        if let gitVersion = Self.gitVersion { return gitVersion }
        return UI.log(verbose: "Fetch Local Git Version", resultOutput: { "Local Git Version: \($0 ?? "unknown")" }, block: {
            let cmd = GitCMD()
            guard cmd.exec("--version") == 0 else { return nil }
            guard let match = try? cmd.outputString.trimmed.match(regex: "[\\d\\.]+")?.first?.first else { return nil }
            Self.gitVersion = match
            return match
        })
    }

    class func lsRemote(at url: URL, args: [String], environment: [String: String]?, combineStderr:Bool = false) throws -> [Substring] {
        var args = ["ls-remote", "-q"] + args
        args.append(url.absoluteString)
        let cmd = GitCMD()
        cmd.showColor = false
        cmd.showOutput = false
        if !cmd.exec(args.joined(separator: " "), env: environment) {
            throw RuntimeError("Git failed: \(url)\n\(cmd.outputString)")
        }
        var output:[Substring] = cmd.outputString.splitLines()
        if combineStderr {
            output += cmd.errorString.splitLines()
        }
        return output
    }

    private func checkSupportFilter(at url: URL) -> Bool {
        guard let localVersion = GitHelper.localVersion() else { return false }
        if localVersion.compare("2.36.1", options: .numeric) == .orderedAscending {
            return false
        }
        guard let remoteVersion = try? GitHelper.remoteVersion(at: url) else {
            return false
        }
        if remoteVersion.hasPrefix("github") {
            return true
        }
        return remoteVersion.compare("2.27.0", options: .numeric) != .orderedAscending
    }

    public struct CloneOptions: CustomStringConvertible {
        public var checkout: Bool = false
        public var recurseSubmodules: Bool = false
        public var partialClone: Bool? = nil
        public var reference: String?

        public static func `default`() -> CloneOptions {
            var opts = self.init()
            opts.checkout = false
            opts.recurseSubmodules = false
            opts.partialClone = nil
            opts.reference = nil
            return opts
        }

        public var description: String {
            var desc = [String]()
            desc << "Checkout: \(checkout)"
            if recurseSubmodules {
                desc << "Recurse Submodules: true"
            }
            if let partialClone = self.partialClone, partialClone {
                desc << "Partial: true"
            }
            if let reference = self.reference {
                desc << "Reference: \(reference)"
            }
            return desc.joined(separator: ", ")
        }
    }

    dynamic
    public func shouldParticalClone(options: CloneOptions) -> Bool {
        return options.partialClone ?? MBSetting.merged.git?.partialClone ?? true
    }

    dynamic
    public func shouldCloneFullObjects() -> Bool {
        return MBSetting.merged.git?.fullClone ?? true
    }

    public func clone(options: CloneOptions) throws {
        guard let urlString = self.url else {
            throw RuntimeError("URL is empty.")
        }
        let message = "Clone from `\(urlString)` (\(options))"
        try UI.log(info: message) {
            let tmpPath = FileManager.temporaryPath(scope: "MBoxGit")
            let tmpDir = tmpPath.deletingLastPathComponent
            let tmpName = tmpPath.lastPathComponent

            try? FileManager.default.removeItem(atPath: tmpPath)
            try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)

            do {
                guard let url = URL(string: urlString) else {
                    throw RuntimeError("URL `\(urlString)` is invalid.")
                }
                var partialClone = self.shouldParticalClone(options: options)
                if partialClone {
                    partialClone = self.checkSupportFilter(at: url)
                }
                if GitHelper.useLibgit2 {
                    let fetchOptions = FetchOptions(url: urlString, tags: true, prune: false, messageBlock: type(of: self).fetchInfoMessageCallback)
                    let cloneOptions = SwiftGit2.CloneOptions(fetchOptions: fetchOptions, checkoutOptions: .init(strategy: .None))
                    _ = try Repository.clone(from: url,
                                             to: URL(fileURLWithPath: tmpPath),
                                             options: cloneOptions,
                                             recurseSubmodules: options.recurseSubmodules).get()
                } else {
                    var args = ["clone", "--progress", urlString, tmpName]
                    if !options.checkout {
                        args.append("--no-checkout")
                    }
                    if options.recurseSubmodules == true {
                        args.append("--recurse-submodules")
                    }
                    if partialClone {
                        UI.log(verbose: "Use No-Blob Mode to clone.")
                        args.append("--filter=blob:none")
                    }
                    if let reference = options.reference {
                        args.append("--reference-if-able")
                        args.append(reference)
                    }
                    try self.execGit(args, workingDirectory: tmpDir, showOutput: true)

                    if partialClone, self.shouldCloneFullObjects() {
                        UI.postRunHooks.append {
                            guard let path = self.path, path.isDirectory else { return }
                            UI.log(warn: "[\(path.lastPathComponent)] Download full repository in the background!")
                            let script = Self.bundle.path(forResource: "partial_clone_to_full_clone", ofType: "sh")!
                            let git = MBCMD(workingDirectory: path)
                            git.bin = "sh"
                            git.detach("\(script.quoted)")
                        }
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
        try self.fetch(reference: true)
    }

    public func fetch(reference: Bool) throws {
        try UI.log(info: "Fetch from remote (tags: true, prune: true)") {
            guard let url = self.url else {
                UI.log(verbose: "The git url is none.")
                return
            }
            if GitHelper.useLibgit2 {
                let opt = FetchOptions(url: url, tags: true, prune: true, messageBlock: type(of: self).fetchVerbMessageCallback)
                try repo.fetch(options: opt).get()
            } else {
                try execGit(["fetch", "--prune", "--tags", "--force", "--progress"], showOutput: false)
                UI.log(verbose: "Check default branch exists") {
                    do {
                        let cmd = try execGit(["symbolic-ref", "refs/remotes/origin/HEAD"])
                        let defaultBranch = cmd.outputString
                        do {
                            try execGit(["show-branch", defaultBranch])
                            UI.log(verbose: "The default branch is `\(defaultBranch)`")
                        } catch {
                            UI.log(verbose: "The default branch is missing (\(defaultBranch)).")
                            _ = try? execGit(["remote", "set-head", "origin", "-a"])
                        }
                    } catch {
                        UI.log(verbose: "The default branch is missing.")
                        _ = try? execGit(["remote", "set-head", "origin", "-a"])
                    }
                }
            }
        }
    }

    public func pull() throws {
        try UI.log(info: "Pull from remote") {
            guard let remoteBranch = self.trackBranch() else {
                throw RuntimeError("No tracked branch to pull.")
            }
            var v = remoteBranch.split(separator: "/")
            let remote = String(v.removeFirst())
            let branch = v.joined(separator: "/")
            if GitHelper.useLibgit2 {
                guard let url = self.url else {
                    throw RuntimeError("The git url is none.")
                }
                let opt = FetchOptions(url: url, tags: true, prune: true, messageBlock: type(of: self).fetchVerbMessageCallback)
                try repo.pull(remote: remote, branch: branch, options: opt).get()
            } else {
                try execGit(["pull", remote, branch, "--force", "--progress"], showOutput: false)
            }
        }
    }

    public func push() throws {
        try UI.log(info: "Push branch to remote") {
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
                try self.execGit(args)
            }
        }
    }
}
