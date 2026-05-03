//
//  isScreenLocked.swift
//  Notchly
//
//  Created by user on 01.04.2026.
//

import CoreGraphics
import Foundation

func isScreenLocked() -> Bool {
    guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else {
        return false
    }

    let isLocked = (dict["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue ?? false
    return isLocked
}
