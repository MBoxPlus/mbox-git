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

@objc(MBoxGit)
open class MBoxGit: NSObject, MBPluginMigrateProtocol {
    public static let sshConfigPath = MBSetting.globalDir.appending(pathComponent: "ssh.config")

    func generateSSHConfig() {
        var content: [String]
        var changed = false
        let path = MBoxGit.sshConfigPath
        if !path.isExists {
            try? FileManager.default.createDirectory(atPath: path.deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
            content = ["""
                Host *
                    GSSAPIAuthentication yes
                    GSSAPIDelegateCredentials no

                """]
            changed = true
        } else {
            content = try! String(contentsOfFile: path, encoding: .utf8).lines()
        }
        let hostKeyChecking = content.contains(where: { $0.trimmed.lowercased().hasPrefix("stricthostkeychecking")
        })
        if !hostKeyChecking {
            content.append("")
            content.append("StrictHostKeyChecking accept-new")
            content.append("")
            changed = true
        }
        if !changed { return }
        UI.log(verbose: "Update `\(path)`") {
            try? content.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    func includeSSHConfig() {
        let mboxPath = MBoxGit.sshConfigPath
        let userPath = SSH2.ConfigFile.Path.User
        let userRealPath = userPath.expandingTildeInPath
        var content = (try? String(contentsOfFile: userRealPath)) ?? ""
        if content.contains("Include \(mboxPath)") {
            return
        }
        UI.log(verbose: "Include `\(mboxPath)` in `\(userPath)`") {
            content = "Include \(mboxPath)\n\n\(content)"
            try? FileManager.default.createDirectory(atPath: userRealPath.deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
            try? content.write(toFile: userRealPath, atomically: true, encoding: .utf8)
        }
    }

    public func installPlugin(from version: String?) throws {
        generateSSHConfig()
        includeSSHConfig()
    }

    public func uninstallPlugin() {
    }
}
