//
//  GitHelper+Alternates.swift
//  MBoxGit
//
//  Created by 詹迟晶 on 2022/8/2.
//  Copyright © 2022 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import SwiftGit2

extension GitHelper {
    public var alternates: [String] {
        return self.allAlternates(maxDeepth: 1)
    }

    private func alternates(atPath objectsPath: String) -> [String] {
        let path = objectsPath.appending(pathComponent: "info/alternates")
        guard path.isFile, let content = try? String(contentsOfFile: path) else { return [] }
        return content.splitLines().compactMap { (string: String) in
            let path = string.trimmed
            if path.hasPrefix("#") { return nil }
            return path.absolutePath(base: objectsPath)
        }
    }

    public func allAlternates(maxDeepth: Int = 5) -> [String] {
        var result = [String]()
        var paths = try! [self.repo.path(for: .objects).get().absoluteString]
        for _ in (0..<maxDeepth) {
            paths = paths.flatMap { self.alternates(atPath: $0) }
            result.append(contentsOf: paths)
            if paths.isEmpty { break }
        }
        return result
    }
}
