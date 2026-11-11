import AppKit
import JfredCore
import SwiftUI

struct ClipboardPreviewPane: View {
    var model: AppModel
    var theme: LauncherTheme

    private var content: ClipboardPreview.Model {
        guard model.results.indices.contains(model.selection) else { return .empty }
        let item = model.results[model.selection]
        if item.kind == "clipboard", let id = UUID(uuidString: item.payload),
           let clip = model.clips.first(where: { $0.id == id }) {
            return ClipboardPreview.model(for: clip)
        }
        if item.kind == "snippet", let id = UUID(uuidString: item.payload),
           let snippet = model.snippets.first(where: { $0.id == id }) {
            return ClipboardPreview.Model(
                headerTitle: snippet.name,
                headerPath: snippet.keyword.isEmpty ? nil : snippet.keyword,
                text: snippetPreviewText(snippet.text)
            )
        }
        return .empty
    }

    var body: some View {
        let preview = content
        VStack(alignment: .leading, spacing: 8) {
            header(preview)
            previewBody(preview)
            Spacer(minLength: 0)
            if !preview.caption.isEmpty {
                Text(preview.caption)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.subtitle)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: theme.rowHighlightRadius, style: .continuous)
                .fill(theme.searchBackground.opacity(0.55))
        )
    }

    @ViewBuilder
    private func header(_ preview: ClipboardPreview.Model) -> some View {
        let title = preview.headerPath ?? preview.headerTitle
        if !title.isEmpty {
            HStack(spacing: 6) {
                if let path = preview.headerIconPath, !path.isEmpty {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 16, height: 16)
                }
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.subtitle)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private func previewBody(_ preview: ClipboardPreview.Model) -> some View {
        if let path = preview.imagePath, !path.isEmpty {
            ClipboardImageFrame(path: path, theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let text = preview.text, !text.isEmpty {
            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .scrollIndicators(.visible)
        } else if let path = preview.headerIconPath, !path.isEmpty {
            VStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                Text(preview.headerTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let headerPath = preview.headerPath, headerPath != preview.headerTitle {
                    Text(headerPath)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.subtitle)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Spacer(minLength: 0)
        }
    }
}

/// Loads a downsampled image off the main thread and draws it aspect-fit
/// inside a white padded frame, never larger than its pixel size.
struct ClipboardImageFrame: View {
    var path: String
    var theme: LauncherTheme
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    let box = CGSize(width: max(0, geo.size.width - 20), height: max(0, geo.size.height - 16))
                    let fitted = fittedSize(image.size, in: box)
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fitted.width, height: fitted.height)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.22), radius: 8, y: 2)
                } else if failed {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.subtitle)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: path) {
            image = nil
            failed = false
            let current = path
            let maxPixel = 900
            let loaded: CGImage? = await Task.detached(priority: .userInitiated) {
                ClipboardPreview.thumbnail(at: current, maxPixelSize: maxPixel)
            }.value
            guard !Task.isCancelled else { return }
            if let loaded {
                image = NSImage(cgImage: loaded, size: NSSize(width: loaded.width, height: loaded.height))
                failed = false
            } else {
                failed = true
            }
        }
    }

    private func fittedSize(_ image: CGSize, in box: CGSize) -> CGSize {
        let width = max(image.width, 1)
        let height = max(image.height, 1)
        let scale = min(1, min(box.width / width, box.height / height))
        return CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
    }
}
