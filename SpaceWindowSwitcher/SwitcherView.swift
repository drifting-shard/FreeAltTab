import SwiftUI

struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel

    var body: some View {
        Group {
            if model.items.isEmpty {
                emptyView
            } else {
                windowStrip
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(stripBackground)
    }

    private var emptyView: some View {
        Image(systemName: "rectangle.dashed")
            .font(.system(size: 20))
            .foregroundStyle(.secondary)
            .frame(width: 72, height: 70)
        .background(tileBackground(selected: false))
    }

    private var windowStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: 10) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        tile(item, selected: index == model.selectedIndex)
                            .id(index)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .onChange(of: model.selectedIndex) { _, index in
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func tile(_ item: WindowItem, selected: Bool) -> some View {
        ZStack {
            appIcon(item.icon)
        }
        .frame(width: 82, height: 74)
        .background(tileBackground(selected: selected))
        .help("\(item.appName): \(item.displayTitle)")
    }

    @ViewBuilder
    private var stripBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func tileBackground(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Color.white.opacity(0.18) : Color.black.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.white.opacity(0.14), lineWidth: selected ? 3 : 1)
            )
    }

    @ViewBuilder
    private func appIcon(_ image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .frame(width: 48, height: 48)
        } else {
            Image(systemName: "app")
                .font(.system(size: 40))
                .frame(width: 48, height: 48)
                .foregroundStyle(.secondary)
        }
    }
}
