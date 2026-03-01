import Foundation
import SwiftUI

// MARK: - Thermal Monitor

@MainActor
final class ThermalMonitor: ObservableObject {
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var shouldReduceFrameRate: Bool = false
    @Published var shouldPauseCamera: Bool = false

    private var observer: NSObjectProtocol?

    var targetFrameRate: Int {
        switch thermalState {
        case .nominal, .fair: return 30
        case .serious: return 15
        case .critical: return 0
        @unknown default: return 15
        }
    }

    func startMonitoring() {
        if observer != nil {
            updateState()
            return
        }

        updateState()

        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateState()
            }
        }
    }

    func stopMonitoring() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    private func updateState() {
        thermalState = ProcessInfo.processInfo.thermalState
        shouldReduceFrameRate = thermalState == .serious
        shouldPauseCamera = thermalState == .critical
    }
}

// MARK: - Thermal Warning View

struct ThermalWarningView: View {
    let thermalState: ProcessInfo.ThermalState

    var body: some View {
        if thermalState == .critical {
            VStack(spacing: 16) {
                Image(systemName: "thermometer.sun.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                Text("Device is Too Warm")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text("Device temperature is critical. Let it cool for a moment, then continue practice.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(24)
        } else if thermalState == .serious {
            Label("Reduced frame rate due to temperature", systemImage: "thermometer.medium")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
