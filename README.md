# AirPods Motion API

## Overview
Swift provides an AirPods motion API that works on supported products like AirPods Pro, AirPods Gen 3, AirPods Max. 

The API gives access to details like Attitude, Rotation Rate, Acceleration, and Gravity. 

This Xcode project demos the use of the AirPods Motion API using `CMHeadphoneMotionManager()` and includes **OpenTrack integration** for head tracking in games and flight simulators.

You can edit the accuracy of the values from the project. 

![](https://i.imgur.com/umV38Ls.gif)

## Features
- Real-time motion data display (Roll, Pitch, Yaw, Rotation Rate, Acceleration, Gravity)
- **OpenTrack UDP Integration**: Stream motion data to OpenTrack running on a PC
- **Reset Orientation**: Set the current head position as center/neutral
- Persistent settings (IP address and port saved between sessions)

## Requirements
- Xcode
- Swift
- iOS 14.0+
- AirPods Pro, AirPods Gen 3, or AirPods Max

## OpenTrack Integration

### Setup Instructions

#### 1. Configure OpenTrack on PC
1. Download and install [OpenTrack](https://github.com/opentrack/opentrack/releases)
2. Open OpenTrack
3. Set **Tracker** to `UDP sender` (or `FreePIE UDP`)
4. Set **Port** to `5555` (or any port you prefer)
5. Set **Protocol** to `FreeTrack 2.0` or appropriate output for your game/simulator
6. Configure **Mappings** as needed for your application
7. Open the port in your firewall if necessary
8. Click **Start** in OpenTrack

#### 2. Configure the iOS App
1. Launch the app on your iOS device
2. Ensure your AirPods are connected
3. Enter your PC's **IP address** in the IP field (e.g., `192.168.1.100`)
4. Enter the **Port** number (default: `5555`)
5. Tap **Start Streaming** to begin sending motion data
6. Use **Reset Orientation** button to set your current head position as center

### Protocol Details
The app uses the FreePIE UDP protocol that OpenTrack accepts:
- Packet format: 6 floats (24 bytes)
- Data: yaw, pitch, roll, x, y, z (rotation in radians, position in arbitrary units)
- Endianness: Little-endian
- Update rate: Matches AirPods motion update rate (typically 60Hz)

### Troubleshooting
- Ensure your iOS device and PC are on the same network
- Check that the firewall allows UDP traffic on the configured port
- Verify the IP address is correct (use `ipconfig` on Windows or `ifconfig`/`ip addr` on Linux/Mac)
- Status label will show "Streaming to OpenTrack" when connected
- If orientation feels inverted, check OpenTrack mapping settings and inversion options

## License
See original project for license information.
