import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case home = "HOME"
    case sound = "SOUND"
    case controls = "CONTROL"
    case device = "DEVICE"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house"
        case .sound: "slider.vertical.3"
        case .controls: "hand.tap"
        case .device: "square.grid.2x2"
        }
    }
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
            DotText(text: "NOTHING", dot: 1.8, gap: 0.9)
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

    /// Floating pill with icon buttons and a small accent underline, as in the Beoplay reference.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                Button { tab = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(tab == item ? CMFTheme.ink : CMFTheme.muted)
                        Capsule()
                            .fill(tab == item ? CMFTheme.red : .clear)
                            .frame(width: 12, height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.rawValue.capitalized)
                .accessibilityLabel(item.rawValue.capitalized)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .background(Color(white: 0.07), in: Capsule())
        .overlay(Capsule().strokeBorder(CMFTheme.lineStrong, lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 12, y: 6)
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }
}
