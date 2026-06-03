//
//  AgentHookInstallState.swift
//  Notchly
//
//  Created by user on 03.06.2026.
//

enum AgentHookInstallState {
    case unknown
    case installing
    case installed
    case notInstalled
    case failed(String)
}
