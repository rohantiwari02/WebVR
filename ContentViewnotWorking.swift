




import SwiftUI
import RealityKit
import RealityKitContent
import WebKit
import Speech // Import Speech framework for speech recognition

enum Tab {
    case viwer
    case home
    case second
}

struct ContentView: View {
    @Binding var results: Array<String>
    @Environment(\.openWindow) private var openWindow
    @State private var takeScreenshot = false
    @State private var capturedImage: UIImage = UIImage()
    @State private var showingCapturedImageSheet = false
    @State private var rootIP = "http://127.0.0.1:5001"
    @State var webViewURL = URL(string: "http://127.0.0.1:5001/brain/GBM/TCGA-02-0004-01Z-00-DX1.d8189fdc-c669-48d5-bc9e-8ddf104caff6.svs")!
    @State var selection: Tab = Tab.home
    @State var searchResult: Array<String> = Array()
    @State var displayImages: Array<String> = Array()
    @State var folderToBeDisplayed: Array<String> = ["brain/GBM","brain/LGG","breast/BRCA","colon/COAD", "liver/CHOL", "liver/LIHC", "lung/LUAD", "lung/LUSC"]
    @State private var sphereEntity: Entity?
    
    // Speech recognition-related variables
    @State private var audioEngine = AVAudioEngine()
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    
    func fetchStringsFromAPI(apiURL: String, completion: @escaping ([String]?, Error?) -> Void) {
        guard let url = URL(string: apiURL) else {
            completion(nil, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                let strings = try JSONDecoder().decode([String].self, from: data)
                completion(strings, nil)
            } catch {
                completion(nil, error)
            }
        }
        
        task.resume()
    }
    
    func getsearch() {
        let apiURL = rootIP+"/search" + webViewURL.path
        print(apiURL)
        openWindow(id: "SecondWindow")
        fetchStringsFromAPI(apiURL: apiURL) { strings, error in
            if let error = error {
                print("Error fetching strings: \(error)")
            } else if let strings = strings {
                DispatchQueue.main.async {  // Ensure UI updates on the main thread
                    self.results = strings
                    print("Received strings: \(strings)")
                }
            }
        }
    }
    
    func getDisplayImages(path: String) {
        let apiURL = rootIP+"/files/"+path
        print(apiURL)
        fetchStringsFromAPI(apiURL: apiURL) { strings, error in
            if let error = error {
                print("Error fetching strings: \(error)")
            } else if let strings = strings {
                DispatchQueue.main.async {  // Ensure UI updates on the main thread
                    self.displayImages = strings
                    print("Received strings: \(strings)")
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                TabView(selection: $selection) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // Left side (25%)
                            List {
                                ForEach(folderToBeDisplayed, id: \.self) { item in
                                    Button(action: {
                                        getDisplayImages(path: item)
                                    }, label: {
                                        Text(item)
                                    })
                                }
                            }
                            .padding(.all)
                            .frame(width: geometry.size.width * 0.25)
                            .background(Color.gray)
                            // Right side (75%)
                            List {
                                ForEach(displayImages, id: \.self) { imageUrl in
                                    Button(action: {
                                        self.webViewURL = URL(string: "\(rootIP)\(imageUrl)")!
                                        self.selection = Tab.viwer
                                    }, label: {
                                        let components = imageUrl.components(separatedBy: "/")
                                        if let lastComponent = components.last {
                                            Text(lastComponent)
                                                .padding(.vertical, 5)
                                                .foregroundColor(.white)
                                        }
                                    })
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }.tag(Tab.home)
                    
                    VStack {
                        WebView(url: webViewURL, takeScreenshot: $takeScreenshot) { image in
                            DispatchQueue.main.async {
                                if let validImage = image {
                                    self.capturedImage = validImage
                                    UIImageWriteToSavedPhotosAlbum(validImage, nil, nil, nil)
                                    self.showingCapturedImageSheet = true
                                }
                            }
                            self.capturedImage = image!
                            self.showingCapturedImageSheet = true
                        }
                        .toolbar {
                            ToolbarItem(placement: .bottomOrnament) { }
                        }
                        .ornament(visibility: .visible, attachmentAnchor: .scene(.bottom), contentAlignment: .center) {
                            HStack {
                                Button(action: {
                                    getsearch()
                                }) {
                                    Label("", systemImage: "magnifyingglass")
                                }
                                .padding(.top, 50)
                                
                                Button(action: {
                                    self.takeScreenshot = true
                                }) {
                                    Label("", systemImage: "camera.viewfinder")
                                }
                                .padding(.top, 50)
                                
                                Button(action: {
                                    self.moveSphereRight()
                                }) {
                                    Label("", systemImage: "arrow.right")
                                }
                                .padding(.top, 50)
                                
                                Button(action: {
                                    self.microphoneRecordAndTranslate()
                                }) {
                                    Label("Record", systemImage: "mic.fill")
                                }
                                .padding(.top, 50)
                            }
                        }
                        
                    }
                    .glassBackgroundEffect()
                    .tabItem {
                        Label("Viewer", systemImage: "eye")
                    }
                    .tag(Tab.viwer)
                }
                .sheet(isPresented: $showingCapturedImageSheet) {
                    Button(action: {
                        self.showingCapturedImageSheet = false
                    }, label: {
                        Text("Close")
                    })
                    Image(uiImage: self.capturedImage)
                        .resizable()
                        .scaledToFit()
                }
            }
            
            // RealityKit content, with disabled hit-testing
            RealityView { content in
                if let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                    content.add(scene)
                    
                    if let sphere = scene.findEntity(named: "pathvis") {
                        print("setting sphere to local var completed")
                        sphereEntity = sphere
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .frame(height: 0)  // Keep the RealityView out of sight if you don't need it right now
            .allowsHitTesting(false)  // Disable hit-testing for RealityView
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // Request permission for microphone and speech recognition
            requestPermissions()
            
            continuousWakeWordDetection()
        }
    }
    
    func requestPermissions() {
        // Request microphone and speech recognition permissions
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized")
            case .denied:
                print("Speech recognition denied")
            case .restricted:
                print("Speech recognition restricted")
            case .notDetermined:
                print("Speech recognition not determined")
            @unknown default:
                fatalError("Unknown speech recognition status")
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("Microphone permission granted")
            } else {
                print("Microphone permission denied")
            }
        }
    }
    
   func continuousWakeWordDetection() {}
//        // Ensure the audio engine is stopped before starting a new recognition task
//        if audioEngine.isRunning {
//            audioEngine.stop()
//            audioEngine.inputNode.removeTap(onBus: 0)
//        }
//
//        // Cancel any previous recognition tasks
//        recognitionTask?.cancel()
//        recognitionTask = nil
//
//        // Configure the audio session for wake word detection
//        let audioSession = AVAudioSession.sharedInstance()
//        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
//        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
//
//        // Create the recognition request for wake word detection
//        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
//        guard let recognitionRequest = recognitionRequest else {
//            fatalError("Unable to create recognition request")
//        }
//
//        // Create the input node from the audio engine
//        let inputNode = audioEngine.inputNode
//        recognitionRequest.shouldReportPartialResults = true
//
//        // Start the speech recognition task to continuously listen for the wake word
//        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
//            if let result = result {
//                // Get the transcribed text
//                let transcription = result.bestTranscription.formattedString
//                print("Recognized text: \(transcription)")
//
//                // Check if the wake word "Hey Webview" is detected
//                if transcription.lowercased().contains("hi agent") {
//                    print("Wake word detected!")
//
//                    // Stop continuous listening
//                    self.audioEngine.stop()
//                    inputNode.removeTap(onBus: 0)
//                    self.recognitionRequest = nil
//                    self.recognitionTask = nil
//
//                    // Delay restarting to avoid rapid retries
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                        // Start actual command listening or other actions
//                        self.microphoneRecordAndTranslate()
//                    }
//                }
//            }
//
//            if error != nil || result?.isFinal == true {
//                // Stop the audio engine and remove the tap
//                self.audioEngine.stop()
//                inputNode.removeTap(onBus: 0)
//                self.recognitionRequest = nil
//                self.recognitionTask = nil
//
//                // Delay restarting to prevent rapid retries
//                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                    // Restart listening for wake word
//                    self.continuousWakeWordDetection()
//                }
//            }
//        }
//
//        // Install a tap on the audio engine's input node to capture audio
//        let recordingFormat = inputNode.outputFormat(forBus: 0)
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
//            recognitionRequest.append(buffer)
//        }
//
//        // Start the audio engine
//        try? audioEngine.start()
//        print("Listening for wake word...")
//    }

    
    // Method to record audio and transcribe it
    func microphoneRecordAndTranslate() {
        // If the audio engine is already running, stop it
        if audioEngine.isRunning {
            print("Stopping audio engine...")
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionTask?.cancel()
            recognitionTask = nil
            return
        }
    
        // If there's an existing recognition task, cancel it
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
    
        // Configure the audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    
        // Create the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create recognition request")
        }
    
        // Create the input node from the audio engine
        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true
    
        // Start the speech recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                // Print the transcribed text
                let transcription = result.bestTranscription.formattedString
                print("Transcribed text: \(transcription)")
            }
    
            if error != nil || result?.isFinal == true {
                // Stop the audio engine and recognition task when complete
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
    
        // Install a tap on the audio engine's input node to capture audio
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            recognitionRequest.append(buffer)
        }
    
        // Start the audio engine
        try? audioEngine.start()
        print("Recording started")
    }


    func stopRecognition(inputNode: AVAudioInputNode) {
        self.audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        self.recognitionRequest = nil
        self.recognitionTask = nil
    }

    
    func moveSphereRight() {
        guard let sphere = sphereEntity else {
            print("Sphere entity not found")
            return
        }
        
        // Define the rightward movement animation
        let moveRight = Transform(translation: SIMD3(x: 0.01, y: 0, z: 0)) // Move 1 unit to the right
        let duration: TimeInterval = 2.0  // Duration of the movement
        
        // Animate the sphere to the right over the specified duration
        sphere.move(to: moveRight, relativeTo: sphere.parent, duration: duration, timingFunction: .linear)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView(results: .constant(["a","b"]))
}
