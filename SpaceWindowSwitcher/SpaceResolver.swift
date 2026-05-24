import CoreGraphics
import Foundation

struct ActiveSpaceWindows {
    let spaceID: Int32
    let windowIDs: [CGWindowID]
}

final class SpaceResolver {
    private typealias ConnectionFunction = @convention(c) () -> Int32
    private typealias GetActiveSpaceFunction = @convention(c) (Int32) -> Int32
    private typealias CopyManagedDisplaySpacesFunction = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopySpacesForWindowsFunction = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias CopyWindowsWithOptionsAndTagsFunction = @convention(c) (
        Int32,
        UInt32,
        CFArray,
        UInt32,
        UnsafeMutablePointer<UInt64>,
        UnsafeMutablePointer<UInt64>
    ) -> Unmanaged<CFArray>?

    private let connection: ConnectionFunction
    private let getActiveSpace: GetActiveSpaceFunction?
    private let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFunction
    private let copySpacesForWindows: CopySpacesForWindowsFunction
    private let copyWindowsWithOptionsAndTags: CopyWindowsWithOptionsAndTagsFunction?

    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
              let connectionSymbol = dlsym(handle, "CGSMainConnectionID"),
              let managedSpacesSymbol = dlsym(handle, "CGSCopyManagedDisplaySpaces"),
              let spacesForWindowsSymbol = dlsym(handle, "CGSCopySpacesForWindows") else {
            return nil
        }

        connection = unsafeBitCast(connectionSymbol, to: ConnectionFunction.self)
        getActiveSpace = dlsym(handle, "CGSGetActiveSpace").map {
            unsafeBitCast($0, to: GetActiveSpaceFunction.self)
        }
        copyManagedDisplaySpaces = unsafeBitCast(managedSpacesSymbol, to: CopyManagedDisplaySpacesFunction.self)
        copySpacesForWindows = unsafeBitCast(spacesForWindowsSymbol, to: CopySpacesForWindowsFunction.self)
        copyWindowsWithOptionsAndTags = dlsym(handle, "CGSCopyWindowsWithOptionsAndTags").map {
            unsafeBitCast($0, to: CopyWindowsWithOptionsAndTagsFunction.self)
        }
    }

    func activeSpaceWindows() -> ActiveSpaceWindows? {
        guard let copyWindowsWithOptionsAndTags else {
            return nil
        }

        let connectionID = connection()
        guard let activeSpaceID = activeSpaceID(connectionID: connectionID) else {
            return nil
        }

        var setTags: UInt64 = 0
        var clearTags: UInt64 = 0x4000000000
        let spaces = [NSNumber(value: activeSpaceID)] as CFArray

        guard let unmanaged = copyWindowsWithOptionsAndTags(connectionID, 0, spaces, 2, &setTags, &clearTags),
              let values = unmanaged.takeRetainedValue() as? [Any] else {
            return nil
        }

        let windowIDs = values.compactMap(cgWindowID)
        return windowIDs.isEmpty ? nil : ActiveSpaceWindows(spaceID: activeSpaceID, windowIDs: windowIDs)
    }

    func activeSpaceID() -> Int32? {
        activeSpaceID(connectionID: connection())
    }

    private func activeSpaceID(connectionID: Int32) -> Int32? {
        guard let getActiveSpace else {
            return nil
        }

        let activeSpaceID = getActiveSpace(connectionID)
        return activeSpaceID > 0 ? activeSpaceID : nil
    }

    func activeSpaceIDs() -> Set<Int> {
        let connectionID = connection()
        guard let unmanaged = copyManagedDisplaySpaces(connectionID),
              let displays = unmanaged.takeRetainedValue() as? [[String: Any]] else {
            return []
        }

        return Set(displays.compactMap { display in
            guard let currentSpace = display["Current Space"] as? [String: Any] else {
                return nil
            }

            return intValue(currentSpace["id64"]) ?? intValue(currentSpace["ManagedSpaceID"])
        })
    }

    func normalSpaceIDs() -> Set<Int> {
        let connectionID = connection()
        guard let unmanaged = copyManagedDisplaySpaces(connectionID),
              let displays = unmanaged.takeRetainedValue() as? [[String: Any]] else {
            return []
        }

        return Set(displays.flatMap { display -> [Int] in
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            return spaces.compactMap { space in
                let type = intValue(space["type"]) ?? -1
                guard type == 0 else {
                    return nil
                }

                return intValue(space["id64"]) ?? intValue(space["ManagedSpaceID"])
            }
        })
    }

    func spaceIDs(for windowID: CGWindowID) -> Set<Int> {
        let connectionID = connection()
        let ids = [NSNumber(value: windowID)] as CFArray

        for selector in [7, 6] {
            guard let unmanaged = copySpacesForWindows(connectionID, Int32(selector), ids),
                  let values = unmanaged.takeRetainedValue() as? [Any] else {
                continue
            }

            let spaceIDs = Set(values.compactMap(intValue))
            if !spaceIDs.isEmpty {
                return spaceIDs
            }
        }

        return []
    }

    private func cgWindowID(_ value: Any?) -> CGWindowID? {
        switch value {
        case let number as NSNumber:
            return CGWindowID(number.uint32Value)
        case let int as Int:
            return CGWindowID(int)
        default:
            return nil
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let int as Int:
            return int
        default:
            return nil
        }
    }
}
