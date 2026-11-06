//
//  SketchEditor.swift
//  A PencilKit canvas for hand-drawing a sketch inside a note.
//

import SwiftUI
import PencilKit

/// A full-screen drawing canvas. Shows the system tool picker and writes back
/// the encoded `PKDrawing` through the `drawing` binding when the sheet closes.
struct SketchEditor: View {
    /// The drawing being edited, as PKDrawing data. `nil` for a fresh sketch.
    @Binding var drawing: Data?

    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            CanvasRepresentable(canvas: canvas, toolPicker: toolPicker, initial: drawing)
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationTitle("Sketch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { saveAndClose() }
                            .fontWeight(.semibold)
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(canvas.drawing.bounds.isEmpty)
                    }
                }
                .confirmationDialog(
                    "Clear the sketch?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) {
                        canvas.drawing = PKDrawing()
                    }
                } message: {
                    Text("This removes everything you've drawn.")
                }
        }
    }

    private func saveAndClose() {
        let current = canvas.drawing
        drawing = current.bounds.isEmpty ? nil : current.dataRepresentation()
        dismiss()
    }
}

/// Bridges a `PKCanvasView` and the system `PKToolPicker` into SwiftUI.
private struct CanvasRepresentable: UIViewRepresentable {
    let canvas: PKCanvasView
    let toolPicker: PKToolPicker
    let initial: Data?

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .systemBackground
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = false
        if let initial, let drawing = try? PKDrawing(data: initial) {
            canvas.drawing = drawing
        }
        // Showing the tool picker needs the canvas to be first responder.
        DispatchQueue.main.async {
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            canvas.becomeFirstResponder()
        }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

// MARK: - Preview thumbnail

/// A small bitmap of a PKDrawing, rendered on a light background so ink is visible
/// whether the app is in light or dark mode.
enum SketchThumbnail {
    static func image(from data: Data?, scale: CGFloat = 2) -> UIImage? {
        guard let data, let drawing = try? PKDrawing(data: data), !drawing.bounds.isEmpty else {
            return nil
        }
        // Add a small margin so strokes aren't clipped to the ink's exact bounds.
        let rect = drawing.bounds.insetBy(dx: -10, dy: -10)
        return drawing.image(from: rect, scale: scale)
    }
}
