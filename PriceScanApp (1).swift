import SwiftUI
import AVFoundation
import VisionKit

// MARK: - Main App
// Minimum Deployment Target: iOS 16.0
@main
struct PriceScanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Models
struct Product: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let barcode: String
}

struct Price: Identifiable {
    let id = UUID()
    let retailer: String
    let price: Double
    let distance: Double
    let inStock: Bool
    let stockLevel: String
    let url: String
}

// MARK: - Product Database
class ProductDatabase {
    static let shared = ProductDatabase()
    
    private let products: [String: Product] = [
        "012000161551": Product(name: "Coca-Cola Classic 12oz Can (12 Pack)", brand: "Coca-Cola", barcode: "012000161551"),
        "07874200619": Product(name: "Tide Laundry Detergent 100oz", brand: "Tide", barcode: "07874200619"),
        "03400001520": Product(name: "Cheerios Cereal 18oz", brand: "General Mills", barcode: "03400001520"),
        "07800011036": Product(name: "Lays Classic Potato Chips", brand: "Frito-Lay", barcode: "07800011036")
    ]
    
    func getProduct(barcode: String) -> Product {
        return products[barcode] ?? Product(
            name: "Product \(barcode.prefix(8))...",
            brand: "Generic Brand",
            barcode: barcode
        )
    }
    
    func generatePrices(for barcode: String) -> [Price] {
        let product = getProduct(barcode: barcode)
        let basePrice = Double.random(in: 5...25)
        
        let retailers = [
            ("Target", 1.2, 0.95, "https://www.target.com/s?searchTerm="),
            ("Walmart", 2.3, 0.87, "https://www.walmart.com/search?q="),
            ("Whole Foods", 0.8, 1.15, "https://www.amazon.com/s?k="),
            ("Costco", 3.5, 0.80, "https://www.costco.com/CatalogSearch?keyword="),
            ("CVS", 0.5, 1.08, "https://www.cvs.com/search?searchTerm=")
        ]
        
        return retailers.map { retailer in
            Price(
                retailer: retailer.0,
                price: basePrice * retailer.2,
                distance: retailer.1,
                inStock: Bool.random() ? true : Double.random(in: 0...1) > 0.2,
                stockLevel: Bool.random() ? "in-stock" : "low-stock",
                url: "\(retailer.3)\(product.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            )
        }.sorted { $0.price < $1.price }
    }
}

// MARK: - Barcode Scanner View (iOS 16+)
struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        if !isScanning {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, BarcodeScannerDelegate {
        let parent: BarcodeScannerView
        
        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }
        
        func didScanBarcode(_ code: String) {
            parent.scannedCode = code
            parent.isScanning = false
        }
    }
}

protocol BarcodeScannerDelegate: AnyObject {
    func didScanBarcode(_ code: String)
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { 
            print("No camera available")
            return 
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Error creating video input: \(error)")
            return
        }
        
        if (captureSession?.canAddInput(videoInput) ?? false) {
            captureSession?.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession?.canAddOutput(metadataOutput) ?? false) {
            captureSession?.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .qr]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            delegate?.didScanBarcode(stringValue)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var isScanning = false
    @State private var scannedCode: String?
    @State private var manualCode = ""
    @State private var product: Product?
    @State private var prices: [Price] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "0f172a"), Color(hex: "1e293b")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("PriceScan")
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "6366f1"), Color(hex: "ec4899")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Find the best prices at local retailers")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // Scanner Section
                        VStack(spacing: 20) {
                            if isScanning {
                                BarcodeScannerView(scannedCode: $scannedCode, isScanning: $isScanning)
                                    .frame(height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(hex: "6366f1"), lineWidth: 3)
                                    )
                            } else {
                                ZStack {
                                    Color.black
                                        .frame(height: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(.gray)
                                        Text("Camera Inactive")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            // Control Buttons
                            HStack(spacing: 15) {
                                if !isScanning {
                                    Button(action: { 
                                        isTextFieldFocused = false
                                        isScanning = true 
                                    }) {
                                        Label("Start Camera", systemImage: "camera")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(hex: "6366f1"), Color(hex: "4f46e5")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .shadow(color: Color(hex: "6366f1").opacity(0.4), radius: 10)
                                    }
                                } else {
                                    Button(action: { isScanning = false }) {
                                        Label("Stop Camera", systemImage: "stop.circle")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(hex: "ef4444"), Color(hex: "dc2626")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .shadow(color: Color(hex: "ef4444").opacity(0.4), radius: 10)
                                    }
                                }
                            }
                            
                            // Manual Input
                            HStack(spacing: 12) {
                                TextField("Enter barcode manually...", text: $manualCode)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color(hex: "0f172a").opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundColor(.white)
                                    .focused($isTextFieldFocused)
                                    .keyboardType(.numberPad)
                                    .submitLabel(.search)
                                    .onSubmit(lookupManualCode)
                                
                                Button(action: lookupManualCode) {
                                    Label("Lookup", systemImage: "magnifyingglass")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: [Color(hex: "6366f1"), Color(hex: "4f46e5")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            
                            // Test Barcodes
                            VStack(spacing: 16) {
                                Text("🧪 Test Barcodes - Tap to Try")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    TestBarcodeButton(name: "Coca-Cola", code: "012000161551") {
                                        isTextFieldFocused = false
                                        lookupBarcode("012000161551")
                                    }
                                    TestBarcodeButton(name: "Tide Detergent", code: "07874200619") {
                                        isTextFieldFocused = false
                                        lookupBarcode("07874200619")
                                    }
                                    TestBarcodeButton(name: "Cheerios", code: "03400001520") {
                                        isTextFieldFocused = false
                                        lookupBarcode("03400001520")
                                    }
                                    TestBarcodeButton(name: "Lays Chips", code: "07800011036") {
                                        isTextFieldFocused = false
                                        lookupBarcode("07800011036")
                                    }
                                }
                            }
                            .padding(.top, 20)
                        }
                        .padding()
                        .background(Color(hex: "1e293b").opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal)
                        
                        // Loading
                        if isLoading {
                            ProgressView("Processing...")
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        // Results
                        if let product = product {
                            VStack(alignment: .leading, spacing: 20) {
                                // Product Info
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(product.name)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color(hex: "6366f1"), Color(hex: "ec4899")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text("\(product.brand) | UPC: \(product.barcode)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "1e293b").opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                
                                // Price Cards
                                ForEach(Array(prices.enumerated()), id: \.element.id) { index, price in
                                    PriceCard(price: price, isBest: index == 0)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .onChange(of: scannedCode) { newValue in
                if let code = newValue {
                    lookupBarcode(code)
                    scannedCode = nil
                }
            }
        }
    }
    
    private func lookupManualCode() {
        guard !manualCode.isEmpty else { return }
        isTextFieldFocused = false
        lookupBarcode(manualCode)
        manualCode = ""
    }
    
    private func lookupBarcode(_ code: String) {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let foundProduct = ProductDatabase.shared.getProduct(barcode: code)
            let foundPrices = ProductDatabase.shared.generatePrices(for: code)
            
            withAnimation(.spring()) {
                product = foundProduct
                prices = foundPrices
                isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views
struct TestBarcodeButton: View {
    let name: String
    let code: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(code)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fontDesign(.monospaced)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(hex: "6366f1").opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "334155"), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PriceCard: View {
    let price: Price
    let isBest: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(price.retailer)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isBest {
                    Text("✨ BEST PRICE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "6366f1"), Color(hex: "4f46e5")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            
            Text(String(format: "$%.2f", price.price))
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "6366f1"), Color(hex: "ec4899")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .foregroundColor(.gray)
                Text("\(String(format: "%.1f", price.distance)) miles away")
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.gray)
                Text("Updated: Today")
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            Text(price.inStock ? (price.stockLevel == "in-stock" ? "In Stock" : "Low Stock") : "Out of Stock")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(price.inStock ? Color(hex: "10b981") : Color(hex: "f59e0b"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(price.inStock ? Color(hex: "10b981").opacity(0.2) : Color(hex: "f59e0b").opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(price.inStock ? Color(hex: "10b981") : Color(hex: "f59e0b"), lineWidth: 1)
                )
            
            Link(destination: URL(string: price.url)!) {
                HStack {
                    Text("View at \(price.retailer)")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color(hex: "6366f1"), Color(hex: "4f46e5")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(hex: "1e293b").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isBest ? Color(hex: "6366f1") : Color(hex: "334155"), lineWidth: isBest ? 2 : 1)
        )
        .shadow(color: isBest ? Color(hex: "6366f1").opacity(0.3) : .clear, radius: 20)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: - Models
struct Product: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let barcode: String
}

struct Price: Identifiable {
    let id = UUID()
    let retailer: String
    let price: Double
    let distance: Double
    let inStock: Bool
    let stockLevel: String
    let url: String
}

// MARK: - Product Database
class ProductDatabase {
    static let shared = ProductDatabase()
    
    private let products: [String: Product] = [
        "012000161551": Product(name: "Coca-Cola Classic 12oz Can (12 Pack)", brand: "Coca-Cola", barcode: "012000161551"),
        "07874200619": Product(name: "Tide Laundry Detergent 100oz", brand: "Tide", barcode: "07874200619"),
        "03400001520": Product(name: "Cheerios Cereal 18oz", brand: "General Mills", barcode: "03400001520"),
        "07800011036": Product(name: "Lays Classic Potato Chips", brand: "Frito-Lay", barcode: "07800011036")
    ]
    
    func getProduct(barcode: String) -> Product {
        return products[barcode] ?? Product(
            name: "Product \(barcode.prefix(8))...",
            brand: "Generic Brand",
            barcode: barcode
        )
    }
    
    func generatePrices(for barcode: String) -> [Price] {
        let product = getProduct(barcode: barcode)
        let basePrice = Double.random(in: 5...25)
        
        let retailers = [
            ("Target", 1.2, 0.95, "https://www.target.com/s?searchTerm="),
            ("Walmart", 2.3, 0.87, "https://www.walmart.com/search?q="),
            ("Whole Foods", 0.8, 1.15, "https://www.amazon.com/s?k="),
            ("Costco", 3.5, 0.80, "https://www.costco.com/CatalogSearch?keyword="),
            ("CVS", 0.5, 1.08, "https://www.cvs.com/search?searchTerm=")
        ]
        
        return retailers.map { retailer in
            Price(
                retailer: retailer.0,
                price: basePrice * retailer.2,
                distance: retailer.1,
                inStock: Bool.random() ? true : Double.random(in: 0...1) > 0.2,
                stockLevel: Bool.random() ? "in-stock" : "low-stock",
                url: "\(retailer.3)\(product.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            )
        }.sorted { $0.price < $1.price }
    }
}

// MARK: - Barcode Scanner
struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, BarcodeScannerDelegate {
        let parent: BarcodeScannerView
        
        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }
        
        func didScanBarcode(_ code: String) {
            parent.scannedCode = code
            parent.isScanning = false
        }
    }
}

protocol BarcodeScannerDelegate: AnyObject {
    func didScanBarcode(_ code: String)
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession?.canAddInput(videoInput) ?? false) {
            captureSession?.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession?.canAddOutput(metadataOutput) ?? false) {
            captureSession?.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didScanBarcode(stringValue)
            captureSession?.stopRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var isScanning = false
    @State private var scannedCode: String?
    @State private var manualCode = ""
    @State private var product: Product?
    @State private var prices: [Price] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "0f172a"), Color(hex: "1e293b")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("PriceScan")
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "6366f1"), Color(hex: "ec4899")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Find the best prices at local retailers")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
                        // Scanner Section
                        VStack(spacing: 20) {
                            if isScanning {
                                BarcodeScannerView(scannedCode: $scannedCode, isScanning: $isScanning)
                                    .frame(height: 300)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(hex: "6366f1"), lineWidth: 3)
                                    )
                            } else {
                                ZStack {
                                    Color.black
                                        .frame(height: 300)
                                        .cornerRadius(16)
                                    
                                    Text("Camera Inactive")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Control Buttons
                            HStack(spacing: 15) {
                                if !isScanning {
                                    Button(action: { isScanning = true }) {
                                        Text("Start Camera")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(hex: "6366f1"), Color(hex: "4f46e5")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(12)
                                            .shadow(color: Color(hex: "6366f1").opacity(0.4), radius: 10)
                                    }
                                } else {
                                    Button(action: { isScanning = false }) {
                                        Text("Stop Camera")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(hex: "ef4444"), Color(hex: "dc2626")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(12)
                                            .shadow(color: Color(hex: "ef4444").opacity(0.4), radius: 10)
                                    }
                                }
                            }
                            
                            // Manual Input
                            HStack(spacing: 12) {
                                TextField("Enter barcode manually...", text: $manualCode)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color(hex: "0f172a").opacity(0.6))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                
                                Button(action: lookupManualCode) {
                                    Text("Lookup")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: [Color(hex: "6366f1"), Color(hex: "4f46e5")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                }
                            }
                            
                            // Test Barcodes
                            VStack(spacing: 16) {
                                Text("🧪 Test Barcodes - Tap to Try")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    TestBarcodeButton(name: "Coca-Cola", code: "012000161551") {
                                        lookupBarcode("012000161551")
                                    }
                                    TestBarcodeButton(name: "Tide Detergent", code: "07874200619") {
                                        lookupBarcode("07874200619")
                                    }
                                    TestBarcodeButton(name: "Cheerios", code: "03400001520") {
                                        lookupBarcode("03400001520")
                                    }
                                    TestBarcodeButton(name: "Lays Chips", code: "07800011036") {
                                        lookupBarcode("07800011036")
                                    }
                                }
                            }
                            .padding(.top, 20)
                        }
                        .padding()
                        .background(Color(hex: "1e293b").opacity(0.6))
                        .cornerRadius(24)
                        .padding(.horizontal)
                        
                        // Loading
                        if isLoading {
                            ProgressView("Processing...")
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        // Results
                        if let product = product {
                            VStack(alignment: .leading, spacing: 20) {
                                // Product Info
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(product.name)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color(hex: "6366f1"), Color(hex: "ec4899")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text("\(product.brand) | UPC: \(product.barcode)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "1e293b").opacity(0.6))
                                .cornerRadius(20)
                                
                                // Price Cards
                                ForEach(Array(prices.enumerated()), id: \.element.id) { index, price in
                                    PriceCard(price: price, isBest: index == 0)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onChange(of: scannedCode) { newValue in
                if let code = newValue {
                    lookupBarcode(code)
                }
            }
        }
    }
    
    private func lookupManualCode() {
        guard !manualCode.isEmpty else { return }
        lookupBarcode(manualCode)
        manualCode = ""
    }
    
    private func lookupBarcode(_ code: String) {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let foundProduct = ProductDatabase.shared.getProduct(barcode: code)
            let foundPrices = ProductDatabase.shared.generatePrices(for: code)
            
            product = foundProduct
            prices = foundPrices
            isLoading = false
        }
    }
}

// MARK: - Supporting Views
struct TestBarcodeButton: View {
    let name: String
    let code: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(code)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fontDesign(.monospaced)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(hex: "6366f1").opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "334155"), lineWidth: 2)
            )
        }
    }
}

struct PriceCard: View {
    let price: Price
    let isBest: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(price.retailer)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isBest {
                    Text("✨ BEST PRICE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "6366f1"), Color(hex: "4f46e5")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                }
            }
            
            Text(String(format: "$%.2f", price.price))
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "6366f1"), Color(hex: "ec4899")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                Text("\(String(format: "%.1f", price.distance)) miles away")
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                Text("Updated: Today")
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            Text(price.inStock ? (price.stockLevel == "in-stock" ? "In Stock" : "Low Stock") : "Out of Stock")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(price.inStock ? Color(hex: "10b981") : Color(hex: "f59e0b"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(price.inStock ? Color(hex: "10b981").opacity(0.2) : Color(hex: "f59e0b").opacity(0.2))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(price.inStock ? Color(hex: "10b981") : Color(hex: "f59e0b"), lineWidth: 1)
                )
            
            Link(destination: URL(string: price.url)!) {
                Text("View at \(price.retailer) →")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "6366f1"), Color(hex: "4f46e5")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(hex: "1e293b").opacity(0.6))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isBest ? Color(hex: "6366f1") : Color(hex: "334155"), lineWidth: isBest ? 2 : 1)
        )
        .shadow(color: isBest ? Color(hex: "6366f1").opacity(0.3) : .clear, radius: 20)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
