//
//  MBoxGit.swift
//  MBoxGit
//
//  Created by 詹迟晶 on 2020/6/22.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

@objc(MBoxGit)
open class MBoxGit: NSObject, MBPluginProtocol {
    public static let sshConfigPath = "~/.mbox/ssh.config"

    func generateSSHConfig() {
        let path = MBoxGit.sshConfigPath.expandingTildeInPath
        if !path.isExists {
            UI.log(verbose: "Generate `\(MBoxGit.sshConfigPath)`") {
                try? FileManager.default.createDirectory(atPath: path.deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
                let content = """
                Host *
                    GSSAPIAuthentication yes
                    GSSAPIDelegateCredentials no

                """
                try? content.write(toFile: path, atomically: true, encoding: .utf8)
            }
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
}
