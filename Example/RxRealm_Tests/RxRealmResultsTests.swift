//
//  RxRealmCollectionsTests.swift
//  RxRealm
//
//  Created by Marin Todorov on 4/30/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest

import RxSwift
import RealmSwift
import RxRealm
import RxTests

class RxRealmResultsTests: XCTestCase {
    
    private func realmInMemory(name: String) -> Realm {
        var conf = Realm.Configuration()
        conf.inMemoryIdentifier = name
        return try! Realm(configuration: conf)
    }
    
    private func clearRealm(realm: Realm) {
        try! realm.write {
            realm.deleteAll()
        }
    }
    
    func testResultsType() {
        let expectation1 = expectationWithDescription("Results<Message> first")
        
        let realm = realmInMemory(#function)
        clearRealm(realm)
        let bag = DisposeBag()
        
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(Results<Message>)
        
        let messages$ = realm.objects(Message).asObservable().shareReplay(1)
        messages$.scan(0, accumulator: {acc, _ in return acc+1})
            .filter { $0 == 4 }.map {_ in ()}.subscribeNext(expectation1.fulfill).addDisposableTo(bag)
        messages$
            .subscribe(observer).addDisposableTo(bag)
        
        //interact with Realm here
        delay(0.1) {
            try! realm.write {
                realm.add(Message("first"))
            }
        }
        delay(0.2) {
            try! realm.write {
                realm.delete(realm.objects(Message).first!)
            }
        }
        delay(0.3) {
            try! realm.write {
                realm.add(Message("second"))
            }
        }
        
        scheduler.start()
        
        waitForExpectationsWithTimeout(0.5) {error in
            //do tests here
            
            XCTAssertTrue(error == nil)
            XCTAssertEqual(observer.events.count, 4)
            let results = observer.events.last!.value.element!
            XCTAssertEqual(results.count, 1)
            XCTAssertEqual(results.first!.text, "second")
        }
    }
    
    func testResultsTypeChangeset() {
        let expectation1 = expectationWithDescription("Results<Message> first")
        
        let realm = realmInMemory(#function)
        clearRealm(realm)
        let bag = DisposeBag()
        
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(String)
        
        let messages$ = realm.objects(Message).asObservableChangeset().shareReplay(1)
        messages$.scan(0, accumulator: {acc, _ in return acc+1})
            .filter { $0 == 3 }.map {_ in ()}.subscribeNext(expectation1.fulfill).addDisposableTo(bag)
        messages$
            .map {results, changes in
                if let changes = changes {
                    return "i:\(changes.inserted) d:\(changes.deleted) u:\(changes.updated)"
                } else {
                    return "initial"
                }
            }
            .subscribe(observer).addDisposableTo(bag)
        
        //interact with Realm here
        delay(0.1) {
            try! realm.write {
                realm.add(Message("first"))
            }
        }
        delay(0.2) {
            try! realm.write {
                realm.delete(realm.objects(Message).first!)
            }
        }
        
        scheduler.start()
        
        waitForExpectationsWithTimeout(0.5) {error in
            //do tests here
            
            XCTAssertTrue(error == nil)
            XCTAssertEqual(observer.events.count, 3)
            XCTAssertEqual(observer.events[0].value.element!, "initial")
            XCTAssertEqual(observer.events[1].value.element!, "i:[0] d:[] u:[]")
            XCTAssertEqual(observer.events[2].value.element!, "i:[] d:[0] u:[]")
        }
    }

}
