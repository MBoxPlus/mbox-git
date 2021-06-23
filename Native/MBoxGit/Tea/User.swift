//
//  User.swift
//  MBoxGit
//
//  Created by 詹迟晶 on 2019/11/28.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

extension MBUser {
    class GitUser: MBUserProtocol {
        init() {
            self.nickname = try? GitHelper.getConfig(for: "user.name")
            self.email = try? GitHelper.getConfig(for: "user.email")
        }
        var nickname: String?
        var email: String?
    }

    @_dynamicReplacement(for: current)
    public static var git_current: MBUserProtocol? {
        if let user = current {
            return user
        }
        return GitUser()
    }
}
