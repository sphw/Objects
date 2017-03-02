//
//  UserManager.swift
//  Ascent
//
//  Created by Sascha Wise on 12/22/16.
//  Copyright © 2016 Sascha Wise. All rights reserved.
//

import UIKit
import ReactiveKit
import Bond
import CoreLocation
import Alamofire
import ReactiveAlamofire
import Locksmith
import CouchbaseLite
public class DataManager {
    public static var shared: DataManager = DataManager()
    public var Classes: ClassesType!
    public var currentUser: (() -> (UserType?))!
    public var database: CBLDatabase!
    public var apiURL: String!
    init(){
    }
    public var objectStore: [String: [String: Object]] = [String: [String: Object]]()
    public func add<T: Object>(_ object: T) {
        if objectStore[String(describing: type(of: object))] == nil {
            objectStore[String(describing: type(of: object))]  = [String: Object]()
        }
        objectStore[String(describing: type(of: object))]?[object.id.value] = object
    }

}
public protocol UserType {
    var cookie: [String: String]? { get set }
}
public protocol ClassesType {
    func type(from json: [String: Any]) -> Object?
    func from(singular: String) -> Self?
    func from(plural: String) -> Self?
}
public protocol DataManagerDelegate {
    func userWasUnauthroized()
}
