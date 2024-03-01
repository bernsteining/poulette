//
//  ContentView.swift
//  poulette
//
//  Created by lisbeth on 3/1/24.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

enum TCPClientError: Error {
    case connectionFailed
    case sendFailed
}

class TCPClient {
    private let address: String
    private let port: Int32
    
    init(address: String, port: Int) {
        self.address = address
        self.port = Int32(port)
    }
    
    func mysend(data: Data) -> Result<Void, TCPClientError> {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 9020
        addr.sin_addr.s_addr = inet_addr(self.address)
        
        let clientSocket = socket(AF_INET, SOCK_STREAM, 0)
        if clientSocket == -1 {
            return .failure(.connectionFailed)
        }
        
        if connect(clientSocket, sockaddr_cast(&addr), socklen_t(MemoryLayout<sockaddr_in>.size)) == -1 {
            return .failure(.connectionFailed)
        }
        
        defer {
            close(clientSocket)
        }
        
        let bytesSent = data.withUnsafeBytes { send(clientSocket, $0, data.count, 0) }
        if bytesSent < 0 {
            return .failure(.sendFailed)
        }
        
        return .success(())
    }
    
    private func sockaddr_cast<T>(_ value: UnsafeMutablePointer<T>) -> UnsafeMutablePointer<sockaddr> {
        return UnsafeMutableRawPointer(value).bindMemory(to: sockaddr.self, capacity: 1)
    }
}

struct ContentView: View {
    @State private var ipAddress: String = ""
    @StateObject private var filePickerDelegate = FilePickerDelegate()

    var body: some View {
        VStack {
            TextField("Enter IP Address", text: $ipAddress)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Choose File") {
                filePickerDelegate.selectFile()
            }
            .padding()
            .disabled(ipAddress.isEmpty)
            
            Button("Send File") {
                sendFile()
            }
            .padding()
            .disabled(ipAddress.isEmpty || filePickerDelegate.selectedFileURL == nil)
        }
        .padding()
        .sheet(isPresented: $filePickerDelegate.isPresented) {
            DocumentPicker(filePickerDelegate: filePickerDelegate)
        }
    }
    
    func sendFile() {
        // This function is called when the "Send File" button is tapped
        // It triggers the action to send the selected file to the IP address
        guard let selectedFileURL = filePickerDelegate.selectedFileURL else { return }
        
        // Implement file sending logic here
        print("Sending file: \(selectedFileURL.absoluteString) to IP: \(ipAddress)")
    }
}

class FilePickerDelegate: NSObject, ObservableObject, UIDocumentPickerDelegate {
    @Published var selectedFileURL: URL?
    @Published var isPresented: Bool = false
    
    func selectFile() {
        isPresented = true
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        selectedFileURL = urls.first
        isPresented = false
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var filePickerDelegate: FilePickerDelegate
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText, .pdf])
        documentPicker.delegate = filePickerDelegate
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Update logic here
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
