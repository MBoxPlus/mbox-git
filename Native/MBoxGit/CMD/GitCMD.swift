//
//  GitCMD.swift
//  MBoxWorkspace
//
//  Created by 詹迟晶 on 2020/3/3.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation
import MBoxCore

open class GitCMD: MBCMD {
    public required init(useTTY: Bool? = nil) {
        super.init(useTTY: useTTY)
        self.setupBin()
    }

    func setupBin() {
        self.bin = "git"
        if showColor {
            self.bin.append(" -c color.ui=always")
        }
        if !self.pager {
            self.bin.append(" --no-pager")
        }
    }

    open var pager = true {
        didSet {
            setupBin()
        }
    }

    open var showColor = true {
        didSet {
            setupBin()
        }
    }
    
}

