//
//  ContentView.swift
//  VisionGraspAssist
//
//  Created by Vincent Tsang on 22/3/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var wristLocation: String = ""
    var body: some View {
        VStack {
            CameraView(wristLocation: $wristLocation)
                .ignoresSafeArea(edges: .all)
            Text("Wrist location: \(self.wristLocation)")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
