#	Functional Concurrency for Swift

![License](https://img.shields.io/github/license/mashape/apistatus.svg)
![Platform](https://img.shields.io/badge/platform-ios%7Cosx-lighthgrey.svg)
![Swift](https://img.shields.io/badge/Swift-3.0-orange.svg)

##	Current State
Early experiments

##	Basics
This framework is an implementation of following principles:
*	provide abstraction that makes
	*	doing right things easier
	*	doing wrong things harder
*	abstraction is based on monads
	*	validation aka Fallible
	*	futures	aka Future
	*	streams aka Stream
	
##	Example
###	Problem
Write a `CarFactory` that will make `Car`s. `Car`s can be made from `Body` and 4 `Wheel`s.
`Body` can be made from `Metal`. `Wheel` can be made from `Rubber`. `Metal` and `Rubber`
can be provided by `MaterialsProvider`. Workers that make all above work concurrently.

###	Solution based on callbacks

	protocol MaterialsProvider {
	  func provideRubber(_ callback: (Rubber) -> Void)
	  func provideMetal(_ callback: (Metal) -> Void)
	}

	protocol CarFactory {
	  var materialsProvider: MaterialsProvider { get }
	  func makeWheel(_ callback: @escaping (Car.Wheel) -> Void)
	  func makeBody(_ callback: @escaping (Car.Body) -> Void)
	  func makeCar(_ callback: @escaping (Car) -> Void)
	}

	extension CarFactory {
	  func makeWheel(_ callback: @escaping (Car.Wheel) -> Void) {
		self.materialsProvider.provideRubber { rubber in
		  // use rubber to make wheel
		  callback(wheel)
		}
	  }

	  func makeBody(_ callback: @escaping (Car.Body) -> Void) {
		self.materialsProvider.provideMetal { metal in
		  // use metal to make body
		  callback(body)
		}
	  }

	  func makeCar(_ callback: @escaping (Car) -> Void) {
		let group = DispatchGroup()

		var body: Car.Body? = nil
		group.enter()
		makeBody {
		  body = $0
		  group.leave()
		}

		let sema = DispatchSemaphore(value: 1)
		let numberOfWheels = 4
		var wheels = Array<Car.Wheel?>(repeating: nil, count: numberOfWheels)
		for index in 0..<numberOfWheels {
		  group.enter()
		  makeWheel {
			sema.wait()
			wheels[index] = $0
			sema.signal()
			group.leave()
		  }
		}

		DispatchQueue.global(qos: .utility).async(group: group) {
		  // use body and wheels to make car
		  callback(car)
		}
	  }
	}

###	Solution based on futures

	protocol MaterialsProvider {
	  func provideRubber() -> Future<Rubber>
	  func provideMetal() -> Future<Metal>
	}

	protocol CarFactory {
	  var materialsProvider: MaterialsProvider { get }
	  func makeWheel() -> Future<Car.Wheel>
	  func makeBody() -> Future<Car.Body>
	  func makeCar() -> Future<Car>
	}

	extension CarFactory {
	  func makeWheel() -> Future<Car.Wheel> {
		return self.materialsProvider
		  .provideRubber()
		  .map { rubber -> Car.Wheel in
			// use rubber to make wheel
			return wheel
		}
	  }

	  func makeBody() -> Future<Car.Body> {
		return self.materialsProvider
		  .provideMetal()
		  .map { metal -> Car.Body in
			// use metal to make body
			return body
		}
	  }

	  func makeCar() -> Future<Car> {
		let futureBody = self.makeBody()
		let futureWheels = (0..<4).map { _ in self.makeWheel() }
		return combine(futureBody, futureWheels)
		  .map { (body, wheels) in
			// use body and wheels to make car
			return car
		}
	  }
	}
	
### Advantages of solution based on futures
*	products are function returns not argument of callback
*	combining products is much simpler	

##	Wishlist
*	Support of latest Swift
*	Futures (50% done)
	*	simple
	*	typesafe
	*	composable
*	Streams (1% done)
	*	unbuffered
	*	buffered
	*	composable
	*	stream producers: (timers, IOs and etc.)
	*	integration with Objective-C runtime (KVO and etc.)
*	Related abstractions implementation (10% done)
	*	validation monad aka Fallible
	*	...
*	Test Coverage (34% done)
*	Performance Measurement (0% done)
*	Documentation (0% done)
*	Sample Code (1% done)
*	Linux support (0% done)	
*	Integrations (0% done)
	*	AppKit
	*	UIKit
	*	server side

##	Documentation
TODO
