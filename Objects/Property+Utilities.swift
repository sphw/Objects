//
//  Propety+Utilities.swift
//  Ascent
//
//  Created by Sascha Wise on 2/22/17.
//  Copyright © 2017 Sascha Wise. All rights reserved.
//

import UIKit
import ReactiveKit
import Bond
extension Property where Value: Any {
    func otoMap<T>(_ cb: @escaping (Value) -> (T)) -> Observable<T>{
        let o = Observable<T>(cb(self.value))
        self.observeNext {
            o.value = cb($0)
        }
        return o
    }
}
extension Property where Value: Equatable {
    func bidirectionalMap<T>(forward: @escaping (Value) -> (T), backward: @escaping (T) -> (Value)) -> Observable<T> {
        let outO = self.otoMap(forward)
        outO.observeNext {
            let v = backward($0)
            if v != self.value {
                self.value = v
            }
        }
        return outO
    }
}
extension SignalProtocol where Element: Any {
    func observableMap<T>(_ cb: @escaping (Element) -> (Observable<T>)) -> Observable<T?>{
        let o = Observable<T?>(nil)
        self.observeNext {
            cb($0).observeNext {
                o.value = $0
            }
        }
        return o
    }
    func toObservable() -> Observable<Element?> {
        let obs = Observable<Element?>(nil)
        let _ = self.observeNext {
            obs.value = $0
        }
        return obs
    }
    func bind(to: Observable<Element> ){
        let _ = self.observeNext {
            to.value = $0
        }
    }
}
