//
//  ContentView.swift
//  poulette
//
//  Created by lisbeth on 3/1/24.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

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
    
    func showAlert(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
    }
    
    func sendFile() {
        let selectedFileURL = filePickerDelegate.selectedFileURL
        
        let port = 9020 // Assuming the port is fixed at 9020
        
        do {
            let inputStream = try InputStream(url: selectedFileURL!)
            inputStream!.open()
            defer {
                inputStream!.close()
            }
            
            let outputStream = try createOutputStream(ipAddress: ipAddress, port: port)
            outputStream.open()
            defer {
                outputStream.close()
            }
            
            var buffer = [UInt8](repeating: 0, count: 4096)
            var bytesRead = 0
            
            repeat {
                bytesRead = inputStream!.read(&buffer, maxLength: buffer.count)
                if bytesRead > 0 {
                    let bytesWritten = outputStream.write(buffer, maxLength: bytesRead)
                    if bytesWritten < 0 {
                        print("Failed to write to output stream")
                        return
                    }
                } else if bytesRead < 0 {
                    print("Failed to read from input stream")
                    return
                }
            } while bytesRead > 0
            
            print("File sent successfully")
        } catch {
            print("Failed to send file: \(error.localizedDescription)")
        }
    }
    
    func createOutputStream(ipAddress: String, port: Int) throws -> OutputStream {
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: ipAddress, port: port, inputStream: nil, outputStream: &outputStream)
        guard let stream = outputStream else {
            throw NetworkError.unableToCreateOutputStream
        }
        return stream
    }
        
}

enum NetworkError: Error {
    case unableToCreateOutputStream
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
