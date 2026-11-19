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
    @Namespace private var tabSlide
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
            .scrollBounceBehavior(.basedOnSize)
            if manager.isConnected { tabBar }
        }
        .frame(width: 400, height: 660)
        .clipped()
        .background(AmbientBackground(tall: true))
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

    /// Floating glass pill with icon buttons; a soft lozenge slides under the active one.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                Button { withAnimation(.smooth(duration: 0.3)) { tab = item } } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 15, weight: tab == item ? .semibold : .regular))
                        .foregroundStyle(tab == item ? CMFTheme.ink : CMFTheme.ink.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if tab == item {
                                Capsule().fill(Color.white.opacity(0.16))
                                    .overlay(alignment: .bottom) {
                                        Circle().fill(CMFTheme.red).frame(width: 4, height: 4).offset(y: -3)
                                    }
                                    .matchedGeometryEffect(id: "tab", in: tabSlide)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(item.rawValue.capitalized)
                .accessibilityLabel(item.rawValue.capitalized)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(4)
        .glass(in: Capsule(), interactive: true)
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }
}
