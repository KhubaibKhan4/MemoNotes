//
//  EmptyBox.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 19/10/2024.
//

import SwiftUI

struct EmptyBox: View {
    var body: some View {
        VStack(alignment: .center) {
            Image(systemName: "list.bullet.clipboard")
                .resizable()
                .frame(width: CGFloat(100),height: CGFloat(150))
                .foregroundColor(.blue)
                .padding()
            Text("No Notes Item Found")
                .font(.headline)
                .foregroundColor(.blue)
        }
    }
}
