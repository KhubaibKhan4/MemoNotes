//
//  SketchSectionView.swift
//  Shows a sketch preview in the note editor and opens the SketchEditor.
//

import SwiftUI

struct SketchSectionView: View {
    @Binding var sketchData: Data?

    @State private var isEditing = false

    var body: some View {
        Section {
            Button {
                isEditing = true
            } label: {
                HStack {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sketchData == nil ? "Add sketch" : "Edit sketch")
                            .foregroundStyle(.primary)
                        if sketchData != nil {
                            Text("Tap to open the drawing canvas")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if sketchData != nil {
                        Menu {
                            Button(role: .destructive) {
                                sketchData = nil
                            } label: {
                                Label("Remove Sketch", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .imageScale(.large)
                        }
                    }
                }
            }
        } header: {
            Text("Sketch")
        }
        .fullScreenCover(isPresented: $isEditing) {
            SketchEditor(drawing: $sketchData)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = SketchThumbnail.image(from: sketchData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary)
                )
        } else {
            Image(systemName: "pencil.and.scribble")
                .foregroundStyle(.tint)
                .imageScale(.large)
                .frame(width: 64, height: 48)
        }
    }
}
