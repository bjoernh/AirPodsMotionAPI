//
//  ViewController.swift
//  HeadTilt
//
//  Created by Pallav Agarwal
//  Twitter: @pallavmac

import UIKit
import CoreMotion
import Network
import SceneKit

class ViewController: UIViewController, CMHeadphoneMotionManagerDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var ipAddressTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var sceneView: SCNView!
    
    let manager = CMHeadphoneMotionManager()
    var udpConnection: NWConnection?
    var referenceAttitude: CMAttitude?
    var isStreamingEnabled = false
    var cubeNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        manager.delegate = self
        
        // Setup 3D scene
        setup3DScene()
        
        // Load saved settings
        if let savedIP = UserDefaults.standard.string(forKey: "ipAddress") {
            ipAddressTextField?.text = savedIP
        } else {
            ipAddressTextField?.text = "192.168.1.100"
        }
        
        if let savedPort = UserDefaults.standard.string(forKey: "port") {
            portTextField?.text = savedPort
        } else {
            portTextField?.text = "5555"
        }
        
        print("Authorized: ", CMAuthorizationStatus.authorized)
        
        manager.startDeviceMotionUpdates(
            to: OperationQueue.current!, withHandler: { [self]
            (deviceMotion, error) -> Void in
         
            if let motion = deviceMotion {
                let attitude = motion.attitude
                
                // Apply reference frame if orientation was reset
                if let reference = referenceAttitude {
                    attitude.multiply(byInverseOf: reference)
                }
                
                let roll = degrees(attitude.roll)
                let pitch = degrees(attitude.pitch)
                let yaw = degrees(attitude.yaw)
                
                let r = motion.rotationRate
                let ac = motion.userAcceleration
                let g = motion.gravity
                
                // Send UDP data if streaming is enabled
                if isStreamingEnabled {
                    sendUDPData(yaw: yaw, pitch: pitch, roll: roll)
                }
                
                // Update 3D object rotation
                update3DRotation(yaw: yaw, pitch: pitch, roll: roll)
                
                DispatchQueue.main.async { [self] in
                    var str = "Attitude:\n"
                    str += degreeText("Roll", roll)
                    str += degreeText("Pitch", pitch)
                    str += degreeText("Yaw", yaw)
                    
                    str += "\nRotation Rate:\n"
                    str += xyzText(r.x, r.y, r.z)
                    
                    str += "\nAcceleration:\n"
                    str += xyzText(ac.x, ac.y, ac.z)
                    
                    str += "\nGravity:\n"
                    str += xyzText(g.x, g.y, g.z)
                    
                    textView.text = str
                }
                
            } else {
                textView.text = "ERROR: \(error?.localizedDescription ?? "")"
            }
        })
    }
    
    func degreeText(_ label: String, _ num: Double) -> String {
        return String(format: "\(label): %.0fº\n", abs(num))
    }
    
    func xyzText(_ x: Double, _ y: Double, _ z: Double) -> String {
        // Absolute value just makes it look nicer
        var str = ""
        str += String(format: "X: %.1f\n", abs(x))
        str += String(format: "Y: %.1f\n", abs(y))
        str += String(format: "Z: %.1f\n", abs(z))
        return str
    }
    
    // MARK: - 3D Scene Setup
    
    func setup3DScene() {
        // Create a new scene
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Set background color
        sceneView.backgroundColor = UIColor.systemGray6
        
        // Allow user to interact with the scene
        sceneView.allowsCameraControl = false
        
        // Show statistics such as fps
        sceneView.showsStatistics = false
        
        // Configure lighting
        sceneView.autoenablesDefaultLighting = true
        
        // Create camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 5)
        scene.rootNode.addChildNode(cameraNode)
        
        // Create a 3D box
        let box = SCNBox(width: 1.5, height: 1.0, length: 0.5, chamferRadius: 0.05)
        
        // Create material for the box with different colors on each face
        let materials = [
            createMaterial(color: .systemRed),      // Front
            createMaterial(color: .systemBlue),     // Right
            createMaterial(color: .systemGreen),    // Back
            createMaterial(color: .systemYellow),   // Left
            createMaterial(color: .systemOrange),   // Top
            createMaterial(color: .systemPurple)    // Bottom
        ]
        box.materials = materials
        
        // Create node for the box
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(x: 0, y: 0, z: 0)
        cubeNode = node
        scene.rootNode.addChildNode(node)
        
        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor.white
        ambientLight.light?.intensity = 300
        scene.rootNode.addChildNode(ambientLight)
    }
    
    func createMaterial(color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor.white
        material.shininess = 0.5
        return material
    }
    
    func update3DRotation(yaw: Double, pitch: Double, roll: Double) {
        // Update the cube rotation on the main thread
        // Use the same values that are sent via UDP
        DispatchQueue.main.async { [weak self] in
            guard let cubeNode = self?.cubeNode else { return }
            
            // Convert degrees to radians
            // Apply rotations to match the orientation being sent via UDP
            let yawRad = -yaw * .pi / 180.0    // Negate for correct direction
            let pitchRad = -pitch * .pi / 180.0 // Negate for correct direction  
            let rollRad = roll * .pi / 180.0
            
            // Apply Euler angles to the cube
            // Order: yaw (Y-axis), pitch (X-axis), roll (Z-axis)
            cubeNode.eulerAngles = SCNVector3(pitchRad, yawRad, rollRad)
        }
    }
    
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        textView.text = "AirPods Connected!"
    }
    
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        textView.text = "AirPods Disconnected :("
        stopStreaming()
    }
    
    func degrees(_ radians: Double) -> Double { return 180 / .pi * radians }
    
    // MARK: - UDP Networking
    
    @IBAction func toggleStreamingButtonTapped(_ sender: UIButton) {
        if isStreamingEnabled {
            stopStreaming()
            sender.setTitle("Start Streaming", for: .normal)
            statusLabel?.text = "Status: Not Streaming"
            statusLabel?.textColor = .systemRed
        } else {
            startStreaming()
            sender.setTitle("Stop Streaming", for: .normal)
            statusLabel?.text = "Status: Streaming to OpenTrack"
            statusLabel?.textColor = .systemGreen
        }
    }
    
    @IBAction func resetOrientationButtonTapped(_ sender: UIButton) {
        // Store the current attitude as reference
        if let motion = manager.deviceMotion {
            referenceAttitude = motion.attitude.copy() as? CMAttitude
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Orientation Reset", 
                                             message: "Current orientation set as center", 
                                             preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
    
    func startStreaming() {
        guard let ipAddress = ipAddressTextField?.text, !ipAddress.isEmpty,
              let portString = portTextField?.text, let port = UInt16(portString) else {
            showAlert(title: "Error", message: "Please enter a valid IP address and port")
            return
        }
        
        // Save settings
        UserDefaults.standard.set(ipAddress, forKey: "ipAddress")
        UserDefaults.standard.set(portString, forKey: "port")
        
        // Setup UDP connection
        let host = NWEndpoint.Host(ipAddress)
        guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
            showAlert(title: "Error", message: "Invalid port number")
            return
        }
        
        udpConnection = NWConnection(host: host, port: portEndpoint, using: .udp)
        
        udpConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("UDP connection ready")
                self?.isStreamingEnabled = true
            case .failed(let error):
                print("UDP connection failed: \(error)")
                self?.isStreamingEnabled = false
                DispatchQueue.main.async {
                    self?.showAlert(title: "Connection Error", message: "Failed to connect: \(error.localizedDescription)")
                }
            default:
                break
            }
        }
        
        udpConnection?.start(queue: .global())
    }
    
    func stopStreaming() {
        isStreamingEnabled = false
        udpConnection?.cancel()
        udpConnection = nil
    }
    
    func sendUDPData(yaw: Double, pitch: Double, roll: Double) {
        guard let connection = udpConnection, connection.state == .ready else {
            return
        }
        
        // Convert degrees to radians for OpenTrack (FreePIE UDP protocol)
        // OpenTrack expects: yaw, pitch, roll, x, y, z (all as floats)
        // Negate yaw and pitch to match OpenTrack's coordinate system where:
        // - Positive yaw = left turn, negative = right turn
        // - Positive pitch = look down, negative = look up
        let yawRad = Float(-yaw * .pi / 180.0)
        let pitchRad = Float(-pitch * .pi / 180.0)
        let rollRad = Float(roll * .pi / 180.0)
        
        // Position data (x, y, z) - set to 0 for rotation-only tracking
        let x: Float = 0.0
        let y: Float = 0.0
        let z: Float = 0.0
        
        // Create byte array for UDP packet (6 floats = 24 bytes)
        // Convert floats to little-endian byte representation via bit pattern
        var data = Data()
        withUnsafeBytes(of: yawRad.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: pitchRad.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: rollRad.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: x.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: y.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: z.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

}

