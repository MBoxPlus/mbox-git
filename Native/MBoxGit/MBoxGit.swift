//
//  MBoxGit.swift
//  MBoxGit
//
//  Created by Whirlwind on 2020/6/22.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2
import MBoxSSH

@objc(MBoxGit)
open class MBoxGit: NSObject, MBPluginMigrateProtocol {

    public func installPlugin(from version: String?) throws {
        if let path = Self.pluginPackage?.resoucePath(for: "ssh.config") {
            try MBoxSSH.linkSSHConfig(path)
        }
    }

    public func uninstallPlugin() {
    }
}
