//
//  GitHelper+Config.swift
//  MBoxGit
//
//  Created by 詹迟晶 on 2019/11/28.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

extension GitHelper {

    public func addConfig(path: String) throws {
        try self.repo.addConfig(path: path, level: .application).get()
    }

    public var configPath: String? {
        return self.repo.isWorkTree ? self.repo.worktreeConfigPath : self.repo.configPath
    }

    public func includeConfig(_ path: String) throws {
        if (try self.isWorkTree && !self.repo.config.usingWorktree().get()) {
            try self.repo.config.useWorktree().get()
        }
        try self.setConfig(key: "include.path", value: path)
    }

    public func setConfig(key: String, value: String) throws {
        try self.repo.config.set(string: value, for: key).get()
    }

    public func getConfig(key: String) throws -> String? {
        try self.repo.config.string(for: key).get()
    }

    public static func getConfig(for path: String) throws -> String? {
        let config = try Config.default().get()
        return try config.string(for: path).get()
    }

    public static func setConfig(key: String, value: String, path: String) throws {
        let config = try Config.open(path: path).get()
        try config.set(string: value, for: key).get()
    }

    // MARK: - Convience
    public var authorName: String? {
        let key = "author.name"
        return try? self.getConfig(key: key) ?? Self.getConfig(for: key)
    }

    public var authorEmail: String? {
        let key = "author.email"
        return try? self.getConfig(key: key) ?? Self.getConfig(for: key)
    }
}
