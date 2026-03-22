//
//  ContentView.swift
//  VisionGraspAssist
//
//  Created by Vincent Tsang on 22/3/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            CameraView()
                .ignoresSafeArea(edges: .all)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
