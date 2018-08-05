//
//  ViewController.swift
//  RxFeedbackQueryTest
//
//  Created by dingqingwang on 8/5/18.
//  Copyright © 2018 topbuzz. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxFeedback

enum RequestType: Int {
    
    case first
    case second
    
    var responseString: String {
        switch self {
        case .first:
            return "response 1 received"
        case .second:
            return "response 2 received"
        }
    }
    
    var debugIdentifier: String {
        switch self {
        case .first:
            return "\n---- request 1 ----\n"
        case .second:
            return "\n---- request 2 ----\n"
        }
    }
}

class Requests {
    
    var array = [RequestType]()
    
    func append(_ req: RequestType) {
        array.append(req)
    }
    
    func all() -> [RequestType] {
        let temp = array
        array.removeAll()
        return temp
    }
    
}

enum Event {
    case none
    case request(RequestType)
    case response(RequestType)
    case clear
}

struct State: Mutable {
    
    var requestsToSend = Requests()

    var response1: String?
    var response2: String?
    
    static func reduce(state: State, event: Event) -> State {
        switch event {
        case .request(let req):
           return state.mutateOne {
                $0.requestsToSend.append(req)
            }
        case .response(let req):
            return state.mutateOne {
                switch req {
                case .first:
                    $0.response1 = req.responseString
                case .second:
                    $0.response2 = req.responseString
                }
            }
        case .clear:
            return state.mutateOne {
                $0.response1 = nil
                $0.response2 = nil
                _ = $0.requestsToSend.all()
            }
        default: return state
        }
    }
}

class ViewController: UIViewController {
    
    private var requestButton1: UIButton!
    private var requestButton2: UIButton!
    private var requestBoth: UIButton!
    private var responseLabel1: UILabel!
    private var responseLabel2: UILabel!
    private var clearButton: UIButton!
    
    private let bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviews()
        setupBinding()
    }
    
    private func setupBinding() {
        
        let UIBindings: (Driver<State>) -> Signal<Event> = bind(self) { me, state in
            let subscriptions = [
                state.map { $0.response1 }.drive(me.responseLabel1.rx.text),
                state.map { $0.response2 }.drive(me.responseLabel2.rx.text)
            ]
            
            let events: [Signal<Event>] = [
                me.requestButton1.rx.tap.map { Event.request(.first) }.asSignal(onErrorJustReturn: .none),
                me.requestButton2.rx.tap.map { Event.request(.second) }.asSignal(onErrorJustReturn: .none),
                me.clearButton.rx.tap.map { Event.clear }.asSignal(onErrorJustReturn: .none)
            ]
            return Bindings(subscriptions: subscriptions, events: events)
        }
        
        let nonUIBindings: (Driver<State>) -> Signal<Event> = react(query: { (state) -> Set<RequestType> in
            let querys = Set(state.requestsToSend.all())
            return querys
        }) { (query) -> Signal<Event> in
            let just = Signal.just(Event.response(query))
            let event = just.delay(2.0)
                .debug(query.debugIdentifier, trimOutput: false)
            return event
        }
        
        Driver
            .system(initialState: State(),
                    reduce: State.reduce,
                    feedback: UIBindings, nonUIBindings)
            .drive()
            .disposed(by: bag)
    }
    
    private func addSubviews() {
        
        let button1 = UIButton()
        button1.frame = CGRect(x: 30, y: 100, width: 160, height: 50)
        button1.titleLabel?.textColor = UIColor.white
        button1.setTitle("tap to send request 1", for: .normal)
        button1.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button1.backgroundColor = UIColor.blue
        
        let button2 = UIButton()
        button2.frame = button1.frame.offsetBy(dx: 200, dy: 0)
        button2.setTitle("tap to send request 2", for: .normal)
        button2.titleLabel?.textColor = UIColor.white
        button2.backgroundColor = UIColor.blue
        button2.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        
        let label1 = UILabel()
        label1.frame = button1.frame.offsetBy(dx: 0, dy: 100)
        label1.backgroundColor = button1.backgroundColor
        label1.textColor = UIColor.white
        label1.font = UIFont.systemFont(ofSize: 14)
        label1.textAlignment = .center
        
        let label2 = UILabel()
        label2.frame = button2.frame.offsetBy(dx: 0, dy: 100)
        label2.backgroundColor = button1.backgroundColor
        label2.textColor = UIColor.white
        label2.font = UIFont.systemFont(ofSize: 14)
        label2.textAlignment = .center
        
        let button3 = UIButton()
        button3.frame = label1.frame.offsetBy(dx: 100, dy: 100)
        button3.titleLabel?.textColor = UIColor.white
        button3.setTitle("clear", for: .normal)
        button3.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button3.backgroundColor = UIColor.blue
        
        let tipLabel1 = UILabel()
        tipLabel1.text = "display response 1"
        tipLabel1.textColor = UIColor.darkText
        tipLabel1.font = UIFont.systemFont(ofSize: 12)
        
        let tipLabel2 = UILabel()
        tipLabel2.text = "display response 2"
        tipLabel2.textColor = UIColor.darkText
        tipLabel2.font = UIFont.systemFont(ofSize: 12)
        
        tipLabel1.frame = label1.frame.offsetBy(dx: 0, dy: -40)
        tipLabel2.frame = label2.frame.offsetBy(dx: 0, dy: -40)
        
        self.requestButton1 = button1
        self.requestButton2 = button2
        self.responseLabel1 = label1
        self.responseLabel2 = label2
        self.clearButton = button3
        
        view.addSubview(button1)
        view.addSubview(button2)
        view.addSubview(label1)
        view.addSubview(label2)
        view.addSubview(clearButton)
        
        view.addSubview(tipLabel1)
        view.addSubview(tipLabel2)
        
    }
}

protocol Mutable {
}

extension Mutable {
    func mutateOne<T>(transform: (inout Self) -> T) -> Self {
        var newSelf = self
        _ = transform(&newSelf)
        return newSelf
    }
    
    func mutate(transform: (inout Self) -> ()) -> Self {
        var newSelf = self
        transform(&newSelf)
        return newSelf
    }
    
    func mutate(transform: (inout Self) throws -> ()) rethrows -> Self {
        var newSelf = self
        try transform(&newSelf)
        return newSelf
    }
}


