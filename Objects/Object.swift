//
//  Object.swift
//  Ascent
//
//  Created by Sascha Wise on 12/30/16.
//  Copyright © 2016 Sascha Wise. All rights reserved.
//

import UIKit
import Alamofire
import ReactiveKit
import ReactiveAlamofire
import Bond
import CouchbaseLite
open class Object: Serializable {
    public var id: Observable<String> = Observable("")
    public var document: CBLDocument?
    public var syncState: Observable<SyncState> = Observable(.Syncing)
    public enum SyncState: Int {
        case NotSynced = 0, Syncing, Synced
    }
    public init(){
        self.id.value = String.random(length: 15)
        let _ = syncState.observeNext {
            if $0 == .Synced {
                self.save()
            }
        }
    }
    open func load(dictionary: [String : Any]) -> Bool {
        guard let id = dictionary["id"] as? String else { return false }
        self.id.value = id
        return true
    }
    required public init?(dictionary: [String : Any]?, add: Bool = true) {
        guard let dictionary = dictionary,
        self.load(dictionary: dictionary) == true else { return nil }
        self.document = DataManager.shared.database.document(withID: self.id.value)
        if add {
            DataManager.shared.add(self)
        }
    }
    open var dictionary: [String : Any] {
        return [
            "id": id.value,
            "syncState": syncState.value.rawValue 
        ]
    }

    public func push() -> SafeSignal<Bool> {
        return Signal<Bool, NoError> { signal in
            let _ = Alamofire.request(DataManager.shared.apiURL +  "\(String(describing: type(of: self)).lowercased())",
                method: .post, parameters: self.dictionary,
                encoding: MessagePackEncoding(), headers: DataManager.shared.currentUser()?.cookie)
                .toDataSignal().observeNext {
                if let d = (try? unpack($0))?.value as? [String: Any] {
                    Object.load(auxData: d)
                    if let object = d["object"] as? [String: Any] {
                        if self.load(dictionary: object) {
                            let _ = self.auxPush().observeNext {
                                signal.completed(with: $0)
                                self.syncState.value = $0 ? SyncState.Synced : SyncState.NotSynced
                            }
                        }else{
                            signal.completed(with: false)
                        }
                    }
                    self.calculateRelationships()
                }
            }
            return NonDisposable.instance
        }
    }

    public func pull() -> SafeSignal<Bool> {
        let u = DataManager.shared.apiURL +  "\(String(describing: type(of: self)).lowercased())/\(self.id.value)"
        return Alamofire.request(u, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: DataManager.shared.currentUser()?.cookie).toDataSignal().map { (data: Data) -> (Bool?) in
            guard let d = (try? unpack(data))?.value as? [String: Any] else { return nil }
            Object.load(auxData: d)
            guard let object = d["object"] as? [String: Any] else { return nil }
            let b = self.load(dictionary: object)
            self.calculateRelationships()
            self.syncState.value = b ? SyncState.Synced : SyncState.NotSynced
            return b
        }.ignoreNil().suppressError(logging: true)
    }
    public func delete() {
        let u = DataManager.shared.apiURL +  "\(String(describing: type(of: self)).lowercased())/\(id.value)"
        let _  = Alamofire.request(u, method: .delete, parameters: nil, encoding: JSONEncoding.default, headers: DataManager.shared.currentUser()?.cookie).validate(statusCode: 200..<300)
    }
    public func remove() {
        let _ = DataManager.shared.objectStore[String(describing: type(of: self))]?.removeValue(forKey: self.id.value)
        try? self.document?.delete()
        
    }
    open func save(depth: Int = 1) {
        document?.properties = self.dictionary as [AnyHashable: Any]
        try? document?.save()
    }
    public func upload(filedName: String, data: Data, mimeType: String) -> SafeSignal<Bool> {
        let u = DataManager.shared.apiURL +  "\(String(describing: type(of: self)).lowercased())/\(self.id.value)/upload/"
        return SafeSignal<Bool> { signal in
            let _ = Alamofire.upload(multipartFormData: { m in
                m.append(data, withName: "files", fileName: "image", mimeType: mimeType)
            }, to: u, headers: DataManager.shared.currentUser()?.cookie, encodingCompletion: {
                switch $0 {
                case .success(let upload, _, _): let _ = upload.toDataSignal().observeNext {
                    if let d = (try? unpack($0))?.value as? [String: Any] {
                        Object.load(auxData: d)
                        if let object = d["object"] as? [String: Any] {
                            signal.completed(with: self.load(dictionary: object))
                        }
                        self.calculateRelationships()
                    }
                }
                case .failure(_): break
                }

            })
            return NonDisposable.instance
        }
    }
    public func file(name: String, url: String?) -> Observable<Data?> {
        let key = "\(name)_coblob_"
        let obs = Observable((self.document?[key] as? CBLBlob)?.content)
        if let url = url,
        obs.value == nil || obs.value?.count == 0 {
            let _ = Alamofire.request(DataManager.shared.apiURL +  url, method: .get
                , parameters: nil, encoding: JSONEncoding.default, headers: DataManager.shared.currentUser()?.cookie).toDataSignal().observeNext {
                    obs.value = $0
                    self.document?[key] = try? CBLBlob(contentType: "image/jpeg", data: $0)
                    try? self.document?.save()
            }
        }
        return obs
    }
    open func calculateRelationships(depth: Int = 0 ) {
        
    }
    open func auxPush() -> Signal<Bool, NoError> {
        return Signal<Bool, NoError> {
            $0.completed(with: true)
            return NonDisposable.instance
        }
    }
}
//MARK: Static Function
extension Object {
    public static func get<T: Object>(id: String?, load: Bool = true) -> Observable<T?> {
        if let id = id {
            let obj = DataManager.shared.objectStore[String(describing: self)]?[id] as? T
            let observable = Observable<T?>((obj ?? self.init(dictionary: DataManager.shared.database.existingDocument(id: id)?.properties as? [String: Any], add: true) as? T))
            if observable.value == nil && load {
                let _  = Alamofire.request(DataManager.shared.apiURL +  "\(String(describing: self).lowercased())/\(id)", method: .get, parameters: nil, encoding: JSONEncoding.default, headers: DataManager.shared.currentUser()?.cookie).toDataSignal().observeNext {
                    if let d = (try? unpack($0))?.value as? [String: Any]  {
                        self.load(auxData: d)
                        if let object = d["object"] as? [String: Any] {
                            observable.value = self.init(dictionary: object) as? T
                            observable.value?.syncState.value = .Synced
                        }
                    }
                }
            }
            return observable
        }else{
            return Observable(nil)
        }
    }
    public static func load(auxData d: [String: Any]) {
        d.forEach { k,v in
            if let c = DataManager.shared.Classes.from(plural: k),
                let a = v as? [[String: Any]]{
                for o in a.flatMap({c.type(from: $0)}) {
                    o.syncState.value = .Synced
                    DataManager.shared.add(o)
                }
            }
        }
    }
    public static func search<T: Object>(string: String, page: Int) -> Observable<[T]?> {
        let obs: Observable<[T]?> = Observable(nil)
        let u = DataManager.shared.apiURL +  "\(String(describing: self))/search/\(string)"
        let _  = Alamofire.request(u, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: DataManager.shared.currentUser()?.cookie).validate(statusCode: 200..<300).toDataSignal().observeNext {
            if let d = ((try? unpack($0))?.value as? [String: Any])?["objects"] as? [[String: Any]]{
                obs.value = d.flatMap({self.init(dictionary:$0, add: true)}) as? [T]
            }
        }
        return obs
    }
}
public struct MessagePackEncoding: ParameterEncoding {
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let dict = parameters else { return urlRequest }
        let data = pack(dict)
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/x-msgpack", forHTTPHeaderField: "Content-Type")
        }
        urlRequest.httpBody = data
        return urlRequest
    }
}
public extension CBLDatabase {
    func existingDocument(id: String) -> CBLDocument?{
        return self.documentExists(id) ? self[id] : nil
    }
}
protocol Serializable {
    init?(dictionary: [String : Any]?, add: Bool)
    func load(dictionary: [String: Any]) -> Bool
    var dictionary: [String: Any] { get }
}
