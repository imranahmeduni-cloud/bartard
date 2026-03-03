// PriceScanApp.swift

// MARK: - Imports
import Foundation
import UIKit

// MARK: - Constants
let apiUrl = "https://api.example.com"

// MARK: - PriceScanApp Class
the class PriceScanApp: UIViewController {

    // MARK: - Properties
    var prices: [Double] = []
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchPrices()
    }
    
    // MARK: - Networking
    func fetchPrices() {
        guard let url = URL(string: apiUrl) else {
            print("Error: Cannot create URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Error handling
            if let error = error {
                print("Error fetching prices: \(error)")
                return
            }
            
            guard let data = data else {
                print("Error: Did not receive data")
                return
            }
            
            do {
                // Assuming JSON data structure
                let decodedData = try JSONDecoder().decode([Double].self, from: data)
                self.prices = decodedData
                self.updateUI() // Ensure UI update happens on main thread
            } catch {
                print("Error decoding data: \(error)")
            }
        }
        
        task.resume()
    }
    
    // MARK: - UI Updates
    func updateUI() {
        DispatchQueue.main.async {
            // Update the UI with fetched prices
            // Example: self.priceLabel.text = "Prices: \(self.prices)"
        }
    }
}