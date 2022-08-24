//
//  MBSetting.swift
//  MBoxGit
//
//  Created by 詹迟晶 on 2022/3/10.
//  Copyright © 2022 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

extension MBSetting {
    open class Git: MBCodableObject {
        @Codable
        open var partialClone: Bool = true

        @Codable
        open var fullClone: Bool = true
    }

    public var git: Git? {
        return self.value(forPath: "git")
    }
}
