//
//  GitHelper+Ignore.swift
//  MBoxGit
//
//  Created by 詹迟晶 on 2021/12/21.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

extension GitHelper {
    public var untrackedIgnoreConfigPath: String? {
        return self.repo.ignoreFile(for: .untrakcedConfig)
    }

    public func ignore(rules: [String], configPath: String) throws {
        try self.repo.ignore(rules: rules, configPath: configPath).get()
    }

    public func ignoreRules(from configPath: String) -> [String] {
        return self.repo.ignoreRules(from: configPath)
    }

    public func checkIgnore(_ path: String) -> Bool {
        var path = path
        if path.isAbsolutePath {
            path = path.relativePath(from: self.path)
        }
        return self.repo.checkIgnore(path)
    }
}
