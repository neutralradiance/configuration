@_exported import Extensions
@_exported import Chalk
@_exported import struct Components.Subject

@dynamicMemberLookup
public struct Configuration: Infallible, Identifiable {
 public init() {}
 public static var defaultValue = Self()
 public var id: Name = .defaultValue
 public var silent = false
 public var uppercase = false
 public var capitalize = true

 public subscript<Value>(
  dynamicMember keyPath: WritableKeyPath<Name, Value>
 ) -> Value {
  get { id[keyPath: keyPath] }
  set { id[keyPath: keyPath] = newValue }
 }

 // TODO: (Advanced (Better)) Syntax highlighting for strings
 // advanced means on call substitution of strings for a certain format such as
 // terminal
 public func callAsFunction(
  _ input: Any...,
  separator: String = " ",
  terminator: String = "\n",
  for subject: Components.Subject? = #fileID,
  of category: Components.Subject? = nil,
  with subcategory: Components.Subject? = nil,
  prefix: String? = nil,
  suffix: String? = nil
 ) {
  if !silent {
   guard let string =
    input.map(String.init(describing:)).joined(separator: separator).wrapped
   else { return }

   let subject = subject?.simplified
   let isError = subject == .error
   let isSuccess = subject == .success
   let header = subject == nil ? .empty :
    subject!.categoryDescription(
     self, for: category, with: subcategory, prefix: prefix, suffix: suffix
    )
   let message =
    "\(string, color: isError ? .red : isSuccess ? .green : .white)"
   
   print(header + .space + message, terminator: terminator)
  }
 }
}

public extension Configuration {
 init(
  identifier: some LosslessStringConvertible,
  _ formal: (some LosslessStringConvertible)? = nil,
  _ informal: (some LosslessStringConvertible)? = nil
 ) {
  self.id = Name(
   id: identifier.description,
   formal: formal?.description,
   informal: informal?.description
  )
 }
}

extension Components.Subject {
 var color: Chalk.Color {
  switch self {
   case .info, .database: return .cyan
   case .error, .session, .queue, .service: return .red
   case .test, .view, .cache, .leaf: return .green
   case .migration: return .magenta
   case .command: return .yellow
   default: return .white
  }
 }

 func logDescription(for: Configuration) -> String {
  let desc =
   """
   \(`for`.uppercase ? rawValue.uppercased() :
    `for`.capitalize ? rawValue.cap : rawValue, color: color, style: .bold)
   """
  return "[ \(desc) ]"
 }

 func categoryDescription(
  _ config: Configuration,
  for category: Components.Subject? = nil,
  with subcategory: Components.Subject? = nil,
  prefix: String? = nil, suffix: String? = nil
 ) -> String {
  guard
   category.notNil || subcategory.notNil || prefix.notNil || suffix.notNil
  else { return logDescription(for: config) }

  let up = config.uppercase
  let cap = config.capitalize

  let pre =
   """
   \((category?.rawValue ?? prefix).unwrap {
    "\(up ? $0.uppercased() : cap ? $0.cap : $0)"
   },
   color: color, style: .bold)
   """

  let sub =
   """
   \(up ? rawValue.uppercased() :
    cap ? rawValue.cap : rawValue, color: color, style: .bold)
   """

  let suff =
   """
   \(
    (subcategory?.rawValue ?? suffix).unwrap {
     " \(up ? $0.uppercased() : cap ? $0.cap : $0)"
    },
    color: color
   )
   """
  return "[ \(pre)\(sub)\(suff) ]"
 }
}

// MARK: Extensions
extension String {
 var cap: String {
  var copy = self
  return String(copy.removeFirst()).capitalized + copy
 }
}

extension Components.Subject {
 var simplified: Self {
  let string = rawValue
  if let last = string.split(separator: "/").last {
   return Self(
    rawValue: String(last.split(separator: .period).first.unsafelyUnwrapped)
   )
  } else {
   return Self(
    rawValue: String(string.split(separator: .period).first.unsafelyUnwrapped)
   )
  }
 }
}

#if canImport(CoreFoundation)
 import CoreFoundation
 import class Foundation.Bundle
 import class Foundation.ProcessInfo
 extension Configuration.Name {
  static var appName: String? {
   Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ??
    Bundle.main.infoDictionary?[kCFBundleExecutableKey as String] as? String
  }

  #if os(macOS)
   static var bundleName: String {
    Bundle.main.bundleIdentifier ?? {
     let info = ProcessInfo.processInfo
     return info.fullUserName
      .split(separator: .space).map { $0.lowercased() }
      .joined(separator: .period)
      .appending(.period + info.processName)
    }()
   }
  #else
   static var bundleName: String {
    Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
   }
  #endif
 }
#else
 import class Foundation.Bundle
 import class Foundation.ProcessInfo
 extension Configuration.Name {
  static var appName: String { ProcessInfo.processInfo.processName }
  static var bundleName: String {
   Bundle.main.bundleIdentifier ?? {
    let info = ProcessInfo.processInfo
    return info.fullUserName
     .split(separator: .space).map { $0.lowercased() }
     .joined(separator: .period)
     .appending(.period + info.processName)
   }()
  }
 }
#endif

public extension Configuration {
 var appName: String? { Name.appName }
 var bundleName: String { Name.bundleName }

 struct Name: Infallible, Hashable {
  public static var defaultValue = Self()
  internal init(
   id: String = Self.bundleName,
   formal: String? = nil,
   informal: String? = nil
  ) {
   self.identifier = id
   self.formal = formal
   self.informal = informal
  }

  public var identifier: String
  public var formal: String? = Self.appName
  public var informal: String? = Self.appName?.lowercased()
 }
}

// MARK: Framework Integration
#if canImport(Vapor)
 import class Vapor.Application
 import protocol Vapor.StorageKey

 public var configuration: Configuration = .defaultValue
 public var name = configuration.name

 extension Configuration: StorageKey {
  public typealias Value = Configuration
 }

 public extension Application {
  typealias Configuration = Configure.Configuration
  var name: String { configuration.name.formal }
  var informalName: String { configuration.name.informal }
  var configuration: Configuration {
   get { storage[Configuration.self] ?? .defaultValue }
   set { storage[Configuration.self] = newValue }
  }
 }
#endif
