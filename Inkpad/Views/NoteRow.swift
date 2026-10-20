//
//  NoteRow.swift
//  Inkpad
//

import SwiftUI

struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 64, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.separator)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(note.updatedAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = note.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.white
        }
    }
}
