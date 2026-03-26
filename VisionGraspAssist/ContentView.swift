//
//  ContentView.swift
//  VisionGraspAssist
//
//  Created by Vincent Tsang on 22/3/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var wristLocation: String = ""
    @State private var guidanceText: String = "請將手移向目標物體"
    @State private var objectName: String = ""
    @State private var speechManager = SpeechManager()
    
    private func reset() {
        self.wristLocation = ""
        self.guidanceText = "請將手移向目標物體"
        self.objectName = ""
        NotificationCenter.default.post(
            name: .resetGuidance,
            object: nil
        )
        speechManager.reset()
    }
    
    var body: some View {
        ZStack {
            CameraView(wristLocation: $wristLocation, guidanceText: $guidanceText, objectName: $objectName)
                .ignoresSafeArea()

            VStack {
                VStack {
                    // Guidance 顯示
                    Text(guidanceText)
                        .font(.title2)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.top, 40)
                }
                Spacer()

                // Reset Button
                Button(action: {
                    // 由 CameraView 內部 reset
                    self.reset()
                }) {
                    Text("物體類型: \(self.objectName)\n手掌位置: \(self.wristLocation)")
                        .font(.title2)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .accentColor(.orange)
                    Text("重新開始")
                        .font(.headline)
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.bottom, 40)
            }
        }
        .onChange(of: guidanceText) { oldValue, newValue in
            if newValue == "✅已抓取" {
                speechManager.speakInstantly("已經攞到物件")
            } else {
                speechManager.speakIfNeeded(newValue)
            }
        }
        .onAppear() {
            speechManager.speakIfNeeded(self.guidanceText)
        }
    }
}

#Preview {
    ContentView()
}
