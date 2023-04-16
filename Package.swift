// swift-tools-version: 5.5

import PackageDescription

let package = Package(
 name: "Configuration",
 products: [.library(name: "Configuration", targets: ["Configuration"])],
 dependencies: [
//  .package(path: "../Core"),
//  .package(path: "../Github/Chalk")
  .package(url: "https://github.com/neutralradiance/core", branch: "main"),
  .package(url: "https://github.com/mxcl/Chalk", branch: "master")
 ],
 targets: [
  .target(
   name: "Configuration",
   dependencies: [
    "Chalk",
    .product(name: "Extensions", package: "Core"),
    .product(name: "Components", package: "Core")
   ]
  ),
  .testTarget(
   name: "ConfigurationTests",
   dependencies: ["Configuration"]
  )
 ]
)
