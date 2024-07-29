//
//  DataStore.swift
//  Webview
//
//  Created by Guttikonda Partha Sai on 05/05/24.
//

import Foundation

class DataStore: ObservableObject {
    @Published var notes: [ResultsDisplay] = []
}

struct GazeData {
    var x: Double
    var y: Double
    var zoom: Double
}