import Cocoa
import Carbon.HIToolbox

final class HotKeys {
    static let shared = HotKeys()
    /// Called when the bindings change.
    var onChange: (() -> Void)?
    /// Called on the main queue when a registered hotkey is pressed.
    var onAction: ((HotKeyAction) -> Void)?
    private(set) var failed: Set<HotKeyAction> = []
    private var refs: [HotKeyAction: EventHotKeyRef] = [:]

    func binding(_ a: HotKeyAction) -> HotKey {
        if let data = UserDefaults.standard.data(forKey: a.defaultsKey), let hk = try? JSONDecoder().decode(HotKey.self, from: data) {
            return hk
        }
        return a.fallback
    }

    func set(_ hk: HotKey?, for a: HotKeyAction) {
        if let hk = hk, hk != a.fallback, let data = try? JSONEncoder().encode(hk) {
            UserDefaults.standard.set(data, forKey: a.defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: a.defaultsKey)
        }
        registerAll()
        onChange?()
    }

    func install() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            let raw = id.id
            DispatchQueue.main.async { HotKeys.handle(raw) }
            return noErr
        }, 1, &spec, nil, nil)
        registerAll()
    }

    static func handle(_ raw: UInt32) {
        guard let action = HotKeyAction(rawValue: raw) else { return }
        shared.onAction?(action)
    }

    func unregisterAll() {
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs = [:]
    }

    func registerAll() {
        unregisterAll()
        failed = []
        for a in HotKeyAction.allCases {
            let hk = binding(a)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(hk.keyCode, hk.modifiers, EventHotKeyID(signature: 0x534E4150, id: a.rawValue),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref = ref { refs[a] = ref } else { failed.insert(a) }
        }
    }
}
