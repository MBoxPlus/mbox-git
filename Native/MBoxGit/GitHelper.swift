//
//  GitHelper.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/6/12.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Cocoa
import MBoxCore
import SwiftGit2
import Alamofire

open class GitHelper: NSObject {

    public static let useLibgit2 = false

    open var path: String!
    open var gitDir: String {
        return self.repo.gitDir!.path
    }
    open var commonDir: String {
        return self.repo.commonDir!.path
    }

    private lazy var allRemotes: [Remote] = (try? self.repo.allRemotes().get()) ?? []

    open lazy var url: String? = {
        guard self.path.isExists else {
            return nil
        }
        var remotes = self.allRemotes
        if remotes.count > 1 {
            let remoteName = self.trackBranch()?.split(separator: "/").first ?? "origin"
            remotes.bringToFirst(where: { $0.name == remoteName })
        }
        return remotes.compactMap{ $0.originURL }.first
    }()

    public convenience init(repo: Repository) {
        self.init()
        self.repo = repo
        self.path = repo.workDir?.path
    }

    public convenience init(path: String? = nil, url: String? = nil) throws {
        self.init()
        var repo: Repository? = nil
        if let path = path {
            self.path = path
            if path.isExists {
                repo = try Repository.at(URL(fileURLWithPath: path)).get()
            }
        }
        if let url = url, !url.isEmpty, repo?.workDir == nil {
            self.url = url
        }
        self.repo = repo
    }

    internal var repo: Repository!

    @discardableResult
    internal func execGit(_ args: [String], workingDirectory: String? = nil, showOutput: Bool = false, quite: Bool = false) throws -> GitCMD {
        let cmd = GitCMD(workingDirectory: workingDirectory ?? self.path)
        cmd.showOutput = showOutput
        cmd.quite = quite
        try cmd.exec(args)
        return cmd
    }

    class var fetchInfoMessageCallback: RemoteCallback.MessageBlock {
        return { message in
            if let message = message {
                UI.log(info: message, newLine: false)
            }
        }
    }

    class var fetchVerbMessageCallback: RemoteCallback.MessageBlock {
        return { message in
            if let message = message {
                UI.log(verbose: message, newLine: false)
            }
        }
    }

    public func change(branch: String, pointTo reference: GitPointer) throws {
        switch reference {
        case .branch(let value):
            _ = try repo.createBranch(branch, baseBranch: value, force: true).get()
        case .commit(let value):
            _ = try repo.createBranch(branch, baseCommit: value, force: true).get()
        case .tag(let value):
            _ = try repo.createBranch(branch, baseTag: value, force: true).get()
        default:
            return
        }
    }
    
    public func reset(commit: String) throws {
        if GitHelper.useLibgit2 {
            try repo.reset(commit: commit).get()
        } else {
            let args = ["reset", "--mixed", commit]
            try self.execGit(args, quite: true)
        }
    }
    
    public func reset(hard: Bool = false) throws {
        if GitHelper.useLibgit2 {
            try repo.reset(type: hard ? .hard : .mixed).get()
        } else {
            var args = ["reset"]
            if hard {
                args << "--hard"
            }
            try self.execGit(args, quite: true)
        }
        if hard {
            try repo.checkout(CheckoutOptions(strategy: .RemoveUntracked)).get()
        }
    }

    public static func create(path: String, initCommit: Bool = true) throws -> Repository {
        let repo = try Repository.create(at: URL(fileURLWithPath: path)).get()
        if initCommit {
            _ = try repo.commit(message: "Init commit").get()
        }
        return repo
    }

    public func eachRepository(_ block: @escaping (String, GitHelper) throws -> Bool) throws {
        var err: Error? = nil
        self.repo.eachRepository { (name, repo) in
            do {
                return try block(name, GitHelper(repo: repo))
            } catch {
                err = error
                return false
            }
        }
        if let error = err {
            throw error
        }
    }

    public func queryGitLabInfo() throws -> [String: Any] {

        guard let url = self.url,
              let gitURL = MBGitURL.init(url) else {
                throw RuntimeError("No valid url!")
        }
        var headers = HTTPHeaders()
        let env = ProcessInfo.processInfo.environment
        let key = gitURL.host.uppercased().replacingOccurrences(of: ".", with: "_")
        if let accessToken = env["\(key)_ACCESS_TOKEN"] {
            headers["Authorization"] = "Bearer \(accessToken)"
        } else if let privateToken = env["\(key)_PRIVATE_TOKEN"] {
            headers["Private-Token"] = privateToken
        }
        let api = "https://\(gitURL.host)/api/v4/projects/\(gitURL.path.urlEncoded)"
        let result = api.syncRequestJSON(headers: headers)
        if result.response?.statusCode == 200,
            let value = result.value as? [String: Any] {
            return value
        } else if let error = result.error {
            throw RuntimeError("Query GitLab API error: \(error.localizedDescription)")
        } else {
            throw RuntimeError("Query GitLab API error: unknown!")
        }
    }

    var filelock: NSDistributedLock?

    public func lock() {
        self.filelock = NSDistributedLock(path: self.gitDir.appending(pathComponent: "index.lock"))
        self.filelock?.try()
    }

    public func unlock() {
        self.filelock?.unlock()
    }
}
