import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case home = "HOME"
    case sound = "SOUND"
    case controls = "CONTROL"
    case device = "DEVICE"
    var id: String { rawValue }
}

struct MenuBarView: View {
    @Bindable var manager: CMFBluetoothManager
    @State private var tab: AppTab
    @Environment(\.openWindow) private var openWindow

    init(manager: CMFBluetoothManager, initialTab: Int = 0) {
        self.manager = manager
        _tab = State(initialValue: AppTab.allCases[initialTab])
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                Group {
                    if manager.isConnected { content } else { EmptyStateView(manager: manager) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            if manager.isConnected { tabBar }
        }
        .frame(width: 400, height: 660)
        .background(CMFTheme.background)
        .foregroundStyle(CMFTheme.ink)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .home: HomeTab(manager: manager)
        case .sound: SoundTab(manager: manager)
        case .controls: ControlsTab(manager: manager)
        case .device: DeviceTab(manager: manager)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            DotText(text: "NOTHING", dot: 2.4, gap: 1.1)
            Spacer()
            Button {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "rectangle.expand.vertical").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CMFTheme.muted)
            }
            .buttonStyle(.plain)
            .help("Open dashboard")
            .padding(.trailing, 8)
            Circle().fill(CMFTheme.red).frame(width: 7, height: 7)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                Button { tab = item } label: {
                    VStack(spacing: 7) {
                        DotText(text: item.rawValue, dot: 1.4, gap: 0.7,
                                color: tab == item ? CMFTheme.ink : CMFTheme.muted)
                        Circle()
                            .fill(tab == item ? CMFTheme.red : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.rawValue.capitalized)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .background(CMFTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(CMFTheme.line).frame(height: 1) }
    }
}
