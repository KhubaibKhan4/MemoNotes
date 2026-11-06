//
//  WelcomeScreen.swift
//  First-run introduction, shown once per install.
//
//  Three short slides covering the features users wouldn't otherwise find:
//  iCloud sync, App Lock and the Share Extension. No sign-in, no accounts —
//  just a tap-through tour. The last slide has a Get Started button.
//

import SwiftUI

struct WelcomeScreen: View {
    /// Called when the user taps Get Started.
    var onDone: () -> Void

    @State private var page = 0

    private struct Slide: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let slides: [Slide] = [
        Slide(
            id: 0,
            symbol: "icloud.and.arrow.up",
            tint: .blue,
            title: "Your notes, everywhere",
            body: "Sign in to iCloud in the Settings app and your notes, checklists and todos sync across your iPhone, iPad and Mac automatically."
        ),
        Slide(
            id: 1,
            symbol: "lock.shield",
            tint: .orange,
            title: "Lock what's private",
            body: "Turn on App Lock in Settings and your notes stay hidden until you unlock with Face ID, Touch ID or your passcode — even in the app switcher."
        ),
        Slide(
            id: 2,
            symbol: "square.and.arrow.up",
            tint: .green,
            title: "Save from any app",
            body: "Share a web page, a chat message or a photo to CloudNote AI from any app's share sheet, and it lands here as a new note or task."
        ),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            TabView(selection: $page) {
                ForEach(slides) { slide in
                    SlideView(slide: slide).tag(slide.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                Button {
                    if page == slides.count - 1 {
                        onDone()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(page == slides.count - 1 ? "Get Started" : "Next")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip") { onDone() }
                    .foregroundStyle(.secondary)
                    .opacity(page == slides.count - 1 ? 0 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private struct SlideView: View {
        let slide: Slide

        var body: some View {
            VStack(spacing: 24) {
                Image(systemName: slide.symbol)
                    .font(.system(size: 88))
                    .foregroundStyle(slide.tint)
                    .padding(.top, 48)
                VStack(spacing: 12) {
                    Text(slide.title)
                        .font(.title).fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text(slide.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Spacer()
            }
        }
    }
}
