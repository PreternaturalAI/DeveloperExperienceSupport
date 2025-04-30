//
//  HelperAgentManager.swift
//  App‑Group Discovery (Minimal)
//
//  Created by ChatGPT on 4/18/25
//

import Foundation
import Security

public enum AppGroupError: Error, CustomStringConvertible {
    case missingEntitlement
    case invalidEntitlementFormat
    case entitlementReadFailed(reason: String)
    
    public var description: String {
        switch self {
            case .missingEntitlement:
                return "No application‑groups entitlement found."
            case .invalidEntitlementFormat:
                return "application‑groups entitlement has unexpected format."
            case .entitlementReadFailed(let reason):
                return "Unable to read entitlement: \(reason)"
        }
    }
}

public struct AppGroup {
    public struct ID: RawRepresentable, Hashable, Codable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public var description: String { rawValue }
    }
    
    public let id: ID
    public let containerURL: URL?
    
    public init(id: ID) {
        self.id = id
        self.containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: id.rawValue)
    }
    
    public static func current() throws -> AppGroup {
        /*guard let first = allIDs().first else {
            throw AppGroupError.missingEntitlement
        }*/
        return AppGroup(id: .init(rawValue: "9GMDZT68HT.ai.preternatural.extension-group"))
    }
    
    public static func allIDs() -> [ID] {
        var seen = Set<ID>()
        var ordered: [ID] = []
        
        func append(_ ids: [ID]) {
            for id in ids where seen.insert(id).inserted {
                ordered.append(id)
            }
        }
        
        do {
            // 1. Current task's entitlement
            append(try readEntitlementFromSelf())
            
            // 2. Main bundle
            append(try readEntitlementIfAccessible(fromBundleAt: Bundle.main.bundleURL))
            
            // If inside app extension, skip rest
            if isAppExtension() {
                return ordered
            }
            
            // 3. Parent app bundle (if any)
            if let parentURL = findParentAppBundleURL() {
                append(try readEntitlementIfAccessible(fromBundleAt: parentURL))
            }
            
            // 4. Sibling app bundles
            for appURL in findAllMatchingAppBundles() {
                append((try? readEntitlementIfAccessible(fromBundleAt: appURL)) ?? [])
            }
        } catch {
            // Silent failure
        }
        
        return ordered
    }
}

// MARK: - Entitlement Utilities (Private)

private extension AppGroup.ID {
    static func wrap(_ strings: [String]) -> [Self] { strings.map(Self.init) }
}

private extension AppGroup {
    static func readEntitlementFromSelf() throws -> [ID] {
        guard let task = SecTaskCreateFromSelf(nil) else {
            throw AppGroupError.entitlementReadFailed(reason: "SecTaskCreateFromSelf failed")
        }
        
        guard let value = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.security.application-groups" as CFString,
            nil
        ) else {
            return []
        }
        
        return try castCFArrayToIDs(value)
    }
    
    static func readEntitlementIfAccessible(fromBundleAt url: URL) throws -> [ID] {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return []
        }
        
        return try readEntitlement(fromBundleAt: url)
    }
    
    static func readEntitlement(fromBundleAt url: URL) throws -> [ID] {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else {
            return []
        }
        
        var infoCF: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoCF
        ) == errSecSuccess,
              let info = infoCF as? [String: Any],
              let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
              let value = entitlements["com.apple.security.application-groups"] else {
            return []
        }
        
        return try castCFArrayToIDs(value as CFTypeRef)
    }
    
    static func castCFArrayToIDs(_ cf: CFTypeRef) throws -> [ID] {
        guard CFGetTypeID(cf) == CFArrayGetTypeID(),
              let array = cf as? [Any] else {
            throw AppGroupError.invalidEntitlementFormat
        }
        
        return array.compactMap { $0 as? String }.map(ID.init)
    }
    
    // MARK: - App Extension Detection
    
    static func isAppExtension() -> Bool {
        let path = Bundle.main.bundlePath
        if path.contains(".appex") {
            return true
        }
        if let _ = Bundle.main.infoDictionary?["NSExtension"] {
            return true
        }
        return false
    }
    
    // MARK: - Bundle Search Helpers
    
    static func findParentAppBundleURL() -> URL? {
        var url = Bundle.main.bundleURL.standardizedFileURL
        while url.pathExtension.lowercased() != "app" {
            let parent = url.deletingLastPathComponent().standardizedFileURL
            if parent == url || parent.pathComponents.count <= 1 {
                return nil
            }
            url = parent
        }
        return url
    }
    
    static func findAllMatchingAppBundles() -> [URL] {
        guard let root = findBuildProductsRoot(),
              FileManager.default.isReadableFile(atPath: root.path) else {
            return []
        }
        
        let execName = Bundle.main.executableURL?.lastPathComponent ?? CommandLine.arguments[0]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        var results: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension.lowercased() == "app" else { continue }
            
            let execPath = item.appendingPathComponent("Contents/MacOS/\(execName)")
            if FileManager.default.isReadableFile(atPath: execPath.path) {
                results.append(item.standardizedFileURL)
            }
        }
        
        return results
    }
    
    static func findBuildProductsRoot() -> URL? {
        var url = Bundle.main.bundleURL.standardizedFileURL
        while url.pathComponents.count > 1 {
            if url.lastPathComponent == "Products" {
                return url
            }
            url = url.deletingLastPathComponent()
        }
        return nil
    }
}
