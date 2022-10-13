//
//  GitCMD.swift
//  MBoxWorkspace
//
//  Created by Whirlwind on 2020/3/3.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation
import MBoxCore

open class GitCMD: MBCMD {
    public required init(useTTY: Bool? = nil) {
        super.init(useTTY: useTTY)
        self.setupBin()
        self.setupArgs()
    }

    dynamic
    open func setupBin() {
        self.bin = "git"
    }

    open func setupArgs() {
        if showColor {
            self.args.append(contentsOf: ["-c", "color.ui=always"])
        }
        if !self.pager {
            self.args.append("--no-pager")
        }
    }

    open var pager = true {
        didSet {
            setupArgs()
        }
    }

    open var showColor = true {
        didSet {
            setupArgs()
        }
    }

    open func exec(_ args: [String]) throws {
        let code: Int32 = self.exec(args.map(\.quoted).joined(separator: " "))
        if code != 0 {
            throw RuntimeError("git \(args.first!) failed!", code: code)
        }
    }
}

