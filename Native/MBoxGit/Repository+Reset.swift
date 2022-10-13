//
//  Repository+Reset.swift
//  MBoxBitsStudio
//
//  Created by kila on 2022/4/21.
//  Copyright © 2022 com.bytedance. All rights reserved.
//

import Foundation
import SwiftGit2
@_implementationOnly import git2

public extension Repository {
    func reset(commit: String) -> Result<(), NSError> {
        let length = commit.lengthOfBytes(using: String.Encoding.utf8)
        let pointer = UnsafeMutablePointer<git_oid>.allocate(capacity: length)
        defer { pointer.deallocate() }
        var result = git_oid_fromstrn(pointer, commit, length)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(domain: "gitError", code: 101, userInfo: ["msg":"git_oid_fromstrn"]))
        }
        var oid = pointer.pointee
        var object: OpaquePointer? = nil
        defer { git_annotated_commit_free(object) }
        result = git_annotated_commit_lookup(&object, self.pointer, &oid)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(domain: "gitError", code: 102, userInfo: ["msg":"git_annotated_commit_lookup"]))
        }
        
        let options_pointer = UnsafeMutablePointer<git_checkout_options>.allocate(capacity: 1)
        defer { options_pointer.deallocate() }
        git_checkout_options_init(options_pointer, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        var options = options_pointer.move()
        
        result = git_reset_from_annotated(self.pointer, object, GIT_RESET_MIXED, &options)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(domain: "gitError", code: 103, userInfo: ["msg":"git_reset"]))
        }
        return .success(())
    }
}
