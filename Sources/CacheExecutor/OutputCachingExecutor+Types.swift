//
//  File.swift
//  
//
//  Created by Norman Barnard on 5/9/21.
//

import Foundation

public enum CacheExecutorError: Error {
    case hashFailure(String)
    case badCommand(reason: String)
    case systemError(Error)
    case fileError(message: String)
}
