import Foundation

/// The MessagePackValue enum encapsulates one of the following types: Nil, Bool, Int, UInt, Float, Double, String, Binary, Array, Map, and Extended.
public enum MessagePackValue {
    case extended(Int8, Data)
}


public enum MessagePackError: Error {
    case invalidArgument
    case insufficientData
    case invalidData
}
