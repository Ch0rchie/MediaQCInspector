import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {

    @ObservedObject var model: QCModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(model.isDropTarget ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundStyle(model.isDropTarget ? Color.accentColor : Color.secondary.opacity(0.35))
                )

            VStack(spacing: 12) {
                Image(systemName: model.isDropTarget ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(model.isDropTarget ? Color.accentColor : Color.secondary)

                Text("Drop media files here")
                    .font(.headline)

                Text("or choose files to add them to the queue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Choose Files") {
                    model.chooseFiles()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: Binding(
                get: { model.isDropTarget },
                set: { model.isDropTarget = $0 }
            ),
            perform: { providers in
                model.handleDrop(providers)
            }
        )
        .accessibilityElement(children: .combine)
    }
}
