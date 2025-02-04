//
//  FontSizeKey.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 16/12/2024.
//

import SwiftUICore

struct FontSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 12
}

extension EnvironmentValues {
    var fontSize: CGFloat {
        get { self[FontSizeKey.self] }
        set { self[FontSizeKey.self] = newValue}
    }
}


struct DynamicFontModifier: ViewModifier {
    
    @Environment(\.fontSize) var fontSize
    
    func body(content: Content) -> some View {
        content.font(.system(size: fontSize))
    }
}

extension View {
    func dynamicFont() -> some View {
        self.modifier(DynamicFontModifier())
    }
}
