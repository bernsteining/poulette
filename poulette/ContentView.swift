import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct ContentView: View {
    @State private var ipAddress: String = "192.168.1.167"
    @State private var port = 9020
    @StateObject private var filePickerDelegate = FilePickerDelegate()
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            TextField("Enter IP Address", text: $ipAddress)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: ipAddress) { newValue in
                    errorMessage = self.isValidIP(ip: newValue) ? nil : "IP Address is invalid."
                }
            
            TextField("Enter Port", value: $port, formatter: {
                let formatter = NumberFormatter()
                formatter.usesGroupingSeparator = false
                return formatter
                }())
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .onChange(of: port) { newValue in
                    errorMessage = 1...65536 ~= port ? nil : "Port must be a number in [1;aa65536]."
                }
                .padding()
            
            Button("Choose File") {
                filePickerDelegate.selectFile()
            }
            .padding()
            .disabled(ipAddress.isEmpty)
            
            Button("Send File") {
                sendFile()
            }
            .padding()
            .disabled(errorMessage != nil || filePickerDelegate.selectedFileURL == nil)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .sheet(isPresented: $filePickerDelegate.isPresented) {
            DocumentPicker(filePickerDelegate: filePickerDelegate)
        }
    }

    func isValidIP(ip: String) -> Bool {
        let parts = ip.components(separatedBy:".")
        let nums = parts.flatMap { Int($0) }
        return parts.count == 4 && nums.count == 4 && !nums.contains { $0 < 0 || $0 > 255 }
}

    func showAlert(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
    }
    
    func sendFile() {
        let selectedFileURL = filePickerDelegate.selectedFileURL
                
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
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType("public.item")!])
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
