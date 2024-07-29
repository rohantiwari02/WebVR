import SwiftUI
import RealityKit
import RealityKitContent
import WebKit

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
    @EnvironmentObject var dataStore: DataStore
    
    func fetchStringsFromAPI(apiURL: String, completion: @escaping ([String]?, Error?) -> Void) {
        // Ensure the URL is valid
        guard let url = URL(string: apiURL) else {
            completion(nil, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Create a URLSession data task
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Handle the error scenario
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Ensure the data is not nil
            guard let data = data else {
                completion(nil, NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            // Attempt to decode the data into an array of strings
            do {
                let strings = try JSONDecoder().decode([String].self, from: data)
                completion(strings, nil)
            } catch {
                completion(nil, error)
            }
        }
        
        // Start the network request
        task.resume()
    }
    
    func getsearch() {
        let apiURL = rootIP + "/search" + webViewURL.path
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
        let apiURL = rootIP + "/files/" + path
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
                CustomWebView(url: webViewURL, takeScreenshot: $takeScreenshot) { image in
                    DispatchQueue.main.async {
                        if let validImage = image {
                            self.capturedImage = validImage
                            print("Image captured ", validImage)
                            
                            // Save the image to the Photos album
                            UIImageWriteToSavedPhotosAlbum(validImage, nil, nil, nil)
                            
                            self.showingCapturedImageSheet = true
                        }
                    }
                    self.capturedImage = image!
                    self.showingCapturedImageSheet = true
                }.toolbar {
                    ToolbarItem(placement: .bottomOrnament) {
                        
                    }
                }.ornament(visibility: .visible, attachmentAnchor: .scene(.bottom), contentAlignment: .center) {
                    HStack {
                        Button(action: {
                            print("open window Action")
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
                    }
                }
                
            }.glassBackgroundEffect()
                .tabItem {
                    Label("Viewer", systemImage: "eye")
                }.tag(Tab.viwer)
        }.sheet(isPresented: $showingCapturedImageSheet) {
            Button(action: {
                self.showingCapturedImageSheet = false
            }, label: {
                Text("close")
            })
            // This is the sheet presentation of the captured image
            Image(uiImage: self.capturedImage)
                .resizable()
                .scaledToFit()
        }
        
    }
}

struct CustomWebView: UIViewRepresentable {
    var url: URL
    @Binding var takeScreenshot: Bool
    var onScreenshotCaptured: (UIImage?) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "gazeHandler")
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if takeScreenshot {
            uiView.takeSnapshot(with: nil, completionHandler: { image, error in
                if let error = error {
                    print("Error taking snapshot: \(error)")
                } else {
                    onScreenshotCaptured(image)
                }
            })
            takeScreenshot = false
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: CustomWebView
        @EnvironmentObject var dataStore: DataStore
        
        init(_ parent: CustomWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "gazeHandler", let body = message.body as? [String: Any] {
                let x = body["x"] as? Double ?? 0.0
                let y = body["y"] as? Double ?? 0.0
                let zoom = body["zoom"] as? Double ?? 1.0
                print("Gaze coordinates: x=\(x), y=\(y), zoom=\(zoom)")
                
                // Store gaze data in DataStore
                DispatchQueue.main.async {
                    self.dataStore.gazeData.append(GazeData(x: x, y: y, zoom: zoom))
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Add any JavaScript you want to inject into the webpage here
            let js = """
            window.addEventListener('mousemove', function(event) {
                var zoom = window.viewer.viewport.getZoom();
                window.webkit.messageHandlers.gazeHandler.postMessage({x: event.clientX, y: event.clientY, zoom: zoom});
            });
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
