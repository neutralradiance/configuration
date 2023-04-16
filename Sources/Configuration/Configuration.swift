@_exported import Extensions
@_exported import Chalk
@_exported import struct Components.Subject

@dynamicMemberLookup
public struct Configuration: Infallible, Identifiable {
 public init() {}
 public static var defaultValue = Self()
 public var id: Name = .defaultValue
 public var silent = false

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
   var message =
    string.map {
     /// - Note: Captures single characters
     switch $0 {
     case "⏎", "→": return "\($0, color: .white, style: .bold)"
     case "{", "}", "[", "]": return "\($0, style: [.bold, .dim])"
     case "-", "—":
      return "\($0, color: .white, style: .bold)"
     default: return "\($0)"
     }
    }.joined()

   var startIndex = message.startIndex
   /// - Note: Index matches are required for matching quotation marks
   Peek(&message, &startIndex) { buffer in
    var excludedRanges: [Range<String.Index>] = .empty
    let lastIndex: String.Index? = buffer.advance(to: "\"")
    guard lastIndex != nil else { return }
    var indexMap =
     buffer.elements.indices.map(where: { index in
      excludedRanges.contains(where: { $0.contains(index) })
     })
    buffer.index = buffer.startIndex
    let matchGroup: [Substring] = ["equals"]
    for char in buffer {
     if indexMap?.contains(buffer.index) ?? false {
      indexMap?.removeFirst()
      continue
     }

     guard let group = matchGroup.map(where: { $0.first! == char })
     else { continue }

     var match: Substring?
     let startIndex = buffer.index(before: buffer.index)
     for word in group {
      // compare each word because we need to know if there are consequetive
      // characters and if on might supercede another by length
      guard let upperBound = buffer.elements.index(
        startIndex, offsetBy: word.count, limitedBy: buffer.endIndex
       ),
       // the index map shouldn't contain the projected bound
       indexMap?.contains(upperBound) ?? false,
       let comparison = buffer[startIndex ..< upperBound]
      else { continue }
      let other = comparison.base
      guard other == word.base else {
       continue
      }
      if let last = match {
       if comparison.count > last.count {
        match = comparison
       }
      } else { match = comparison }
     }

     //     while let nextIndex = buffer.advance(to: "\"") {
     //      if let startIndex = lastIndex {
     //       let endIndex = buffer.index(nextIndex, offsetBy: 1)
     //       let range = startIndex ..< endIndex
     //       guard let match = buffer[range] else { break }
     //       let insert = "\(match, color: .yellow, style: .bold)"
     //       buffer.removeSubrange(startIndex ..< endIndex)
     //       buffer.insert(contentsOf: insert, at: startIndex)
     //       guard
     //        let newIndex =
     //        buffer.index(buffer.index, offsetBy: insert.count, limitedBy: buffer.endIndex)
     //       else { break }
     //       excludedRanges.append(buffer.index ..< newIndex)
     //       buffer.index = newIndex
     //       lastIndex = nil
     //      } else {
     //       lastIndex = nextIndex
     //      }
     //     }

     if let match {
      let insert = "\(match, color: .yellow)"
      buffer.removeSubrange(insert.range)
      buffer.insert(contentsOf: insert, at: buffer.index)
      guard let newIndex = buffer.elements.index(
       startIndex, offsetBy: insert.count, limitedBy: buffer.endIndex
      )
      else { break }
      let range = startIndex ..< newIndex
      excludedRanges.append(range)
      buffer.index = newIndex
      if let map = indexMap {
       for index in map.indices {
        if range.contains(map[index]) {
         indexMap?.remove(at: index)
        } else { break }
       }
      }
      continue
     }
    }
   }

   let subject = subject?.simplified
   let isError = subject == .error
   let isSuccess = subject == .success
   let header = subject == nil ? .empty :
    subject!.categoryDescription(
     for: category, with: subcategory, prefix: prefix, suffix: suffix
    )
   message = "\(message, color: isError ? .red : isSuccess ? .green : .white)"
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

 var logDescription: String {
  let desc = "\(rawValue.uppercased(), color: color, style: .bold)"
  return "[ \(desc) ]"
 }

 func categoryDescription(
  for category: Components.Subject? = nil,
  with subcategory: Components.Subject? = nil,
  prefix: String? = nil, suffix: String? = nil
 ) -> String {
  guard
   category.notNil || subcategory.notNil || prefix.notNil || suffix.notNil
  else { return logDescription }

  let pre =
   """
   \((category?.rawValue ?? prefix).unwrap { "\($0.uppercased())" },
     color: color, style: .bold)
   """
  let sub = "\(rawValue.uppercased(), color: color, style: .bold)"
  let suff =
   """
   \((subcategory?.rawValue ?? suffix).unwrap { " \($0.uppercased())" },
     color: color)
   """
  return "[ \(pre)\(sub)\(suff) ]"
 }
}

// MARK: Extensions
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
