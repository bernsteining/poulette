import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct Message {
    let msg: String
    let error: Bool
}

struct ContentView: View {
    @State private var ipAddress: String = "192.168.1.167"
    @State private var port = 9020
    @StateObject private var filePickerDelegate = FilePickerDelegate()
    @State private var message: Message?

    var body: some View {
        VStack {
            TextField("Enter IP Address", text: $ipAddress)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: ipAddress) { newValue in
                    message = self.isValidIP(ip: newValue) ? nil : Message(msg:"IP Address is invalid.", error:true)
                }
            
            TextField("Enter Port", value: $port, formatter: {
                let formatter = NumberFormatter()
                formatter.usesGroupingSeparator = false
                return formatter
                }())
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .onChange(of: port) { newValue in
                    message = 1...65536 ~= port ? nil : Message(msg:"Port must be a number in [1;65536].", error: true)
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
            .disabled(message != nil || filePickerDelegate.selectedFileURL == nil)

            if let m = message {
                Text(m.msg)
                    .foregroundColor(m.error == true ? .red : .green)
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

    
    func sendFile() {
        let selectedFileURL = filePickerDelegate.selectedFileURL
                
        do {
            let inputStream = try InputStream(url: selectedFileURL!)
            inputStream!.open()
            defer {inputStream!.close()}
            
            let outputStream = try createOutputStream(ipAddress: ipAddress, port: port)
            outputStream.open()
            defer {outputStream.close()}
            
            var buffer = [UInt8](repeating: 0, count: 8192)
            repeat {
                let read = inputStream!.read(&buffer, maxLength: buffer.count)
                outputStream.write(buffer, maxLength: read)
            } while inputStream!.hasBytesAvailable
            
            message = Message(msg: "File sent successfully", error: false)
        } catch {
            message = Message(msg: "Couldn't send file", error: true)
        }
    }
    
    func createOutputStream(ipAddress: String, port: Int) throws -> OutputStream {
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: ipAddress, port: port, inputStream: nil, outputStream: &outputStream)
        guard let stream = outputStream else {throw NetworkError.unableToCreateOutputStream}
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
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
