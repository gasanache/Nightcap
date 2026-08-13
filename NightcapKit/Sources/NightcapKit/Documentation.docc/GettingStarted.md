# Getting Started with NightcapKit

Learn how to integrate NightcapKit into your macOS application to manage Wine bottles and run Windows programs.

## Overview

NightcapKit provides a high-level API for managing Wine bottles—isolated Windows environments that contain their own registry, installed programs, and configuration. This guide walks you through the basic setup and common operations.

## Prerequisites

Before using NightcapKit, ensure that:

1. Your app runs on macOS 15.0 or later
2. NightcapWine is installed via ``NightcapWineInstaller``
3. Rosetta 2 is installed (for Apple Silicon Macs)

## Adding NightcapKit to Your Project

Add NightcapKit as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(path: "../NightcapKit")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["NightcapKit"]
    )
]
```

## Installing NightcapWine

Before managing bottles, you need to install the Wine runtime:

```swift
import NightcapKit

// Check if NightcapWine is installed
if !NightcapWineInstaller.isNightcapWineInstalled() {
    // Download and install NightcapWine
    let tarballURL = // ... download NightcapWine tarball
    do {
        try NightcapWineInstaller.install(from: tarballURL)
    } catch {
        print("Install failed: \(error.localizedDescription)")
    }
}

// Check for updates
let (shouldUpdate, newVersion) = await NightcapWineInstaller.shouldUpdateNightcapWine()
if shouldUpdate {
    print("Update available: \(newVersion)")
}
```

## Creating a Bottle

Create an isolated Wine environment for your Windows applications:

```swift
import NightcapKit

// Create a bottle at a specific location
let bottleURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("MyApp")
    .appendingPathComponent("Bottles")
    .appendingPathComponent("MyBottle")

// Initialize the bottle
let bottle = Bottle(bottleUrl: bottleURL)

// Configure bottle settings
bottle.settings.name = "My Windows Environment"
bottle.settings.windowsVersion = .win10
```

## Running a Windows Program

Execute a Windows application within a bottle:

```swift
import NightcapKit

@MainActor
func runProgram(at url: URL, in bottle: Bottle) async throws {
    // Run the program
    try await Wine.runProgram(at: url, bottle: bottle)
}

// With custom arguments and environment
@MainActor
func runWithOptions(at url: URL, in bottle: Bottle) async throws {
    let environment = ["WINEDEBUG": "-all"]
    try await Wine.runProgram(
        at: url,
        args: ["-windowed"],
        bottle: bottle,
        environment: environment
    )
}
```

## Discovering Installed Programs

Find Windows executables in a bottle:

```swift
import NightcapKit

@MainActor
func discoverPrograms(in bottle: Bottle) {
    // Programs are automatically populated when loading a bottle
    for program in bottle.programs {
        print("Found: \(program.name)")
        
        // Check program architecture
        if let arch = program.peFile?.architecture.toString() {
            print("  Architecture: \(arch)")
        }
    }
    
    // Access pinned programs
    for (pin, program, _) in bottle.pinnedPrograms {
        print("Pinned: \(pin.name)")
    }
}
```

## Configuring Performance Settings

Optimize bottles for different scenarios:

```swift
import NightcapKit

@MainActor
func configurePerformance(bottle: Bottle) {
    // Enable DXVK for better DirectX performance
    bottle.settings.dxvk = true
    bottle.settings.dxvkAsync = true
    
    // Enable Metal HUD for debugging
    bottle.settings.metalHud = true
    
    // Use performance preset
    bottle.settings.performancePreset = .performance
    
    // For Unity games
    bottle.settings.performancePreset = .unity
}
```

## Next Steps

- Learn about the <doc:Architecture> to understand how NightcapKit components work together
- Explore ``BottleSettings`` for all available configuration options
- See ``Wine`` for advanced Wine process management
