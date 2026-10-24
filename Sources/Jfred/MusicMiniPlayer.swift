import AppKit
import SwiftUI

struct MusicMiniPlayer: View {
    var model: AppModel
    var close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            nowPlaying
            controls
            search
            results
        }
        .frame(width: 420, height: 560)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0x1C1C1E))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundStyle(Color(hex: 0xC77DFF))
            Text("Music")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button(action: { model.refreshMusicPanel() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 42)
    }

    private var nowPlaying: some View {
        HStack(spacing: 14) {
            ZStack {
                if let path = model.musicArtPath, let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x6A2C91), Color(hex: 0x241033)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "music.note")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.musicNowTitle.isEmpty ? "Nothing playing" : model.musicNowTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                Text(model.musicNowArtist.isEmpty ? "Music.app" : model.musicNowArtist)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                Text(model.musicNowPlaying ? "Playing" : "Paused")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(model.musicNowPlaying ? Color(hex: 0x7BE0A3) : .white.opacity(0.4))
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var controls: some View {
        HStack(spacing: 26) {
            Button(action: { _ = MusicService.previous(); model.refreshMusicPanel() }) {
                Image(systemName: "backward.fill").font(.system(size: 18))
            }
            Button(action: { _ = MusicService.playPause(); model.refreshMusicPanel() }) {
                Image(systemName: model.musicNowPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 42))
            }
            Button(action: { _ = MusicService.next(); model.refreshMusicPanel() }) {
                Image(systemName: "forward.fill").font(.system(size: 18))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
            TextField("Search Music", text: model.bind(\.musicSearch))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit { model.searchMusic() }
            Button("Search") { model.searchMusic() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: 0xC77DFF))
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if model.musicTracks.isEmpty {
                    Text("Search your Music library, or use play <song> in the launcher.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(30)
                } else {
                    ForEach(model.musicTracks) { track in
                        Button {
                            model.playMusic(track)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: track.isPlaylist ? "music.note.list" : "music.note")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(track.title)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.white.opacity(0.48))
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.08)
                    }
                }
            }
        }
        .padding(.top, 6)
    }
}
