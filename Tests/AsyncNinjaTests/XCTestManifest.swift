//
//  Copyright (c) 2016-2017 Anton Mironov
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom
//  the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import XCTest

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
#else
  public func allTests() -> [XCTestCaseEntry] {
    return [
      testCase(BatchFutureTests.allTests),
      testCase(CachableValueTests.allTests),
      testCase(ChannelTests.allTests),
      testCase(EventSource_CombineTests.allTests),
      testCase(EventSource_FlatMapFuturesTests.allTests),
      testCase(EventSource_MapTests.allTests),
      testCase(EventSource_Merge2Tests.allTests),
      testCase(EventSource_ScanTests.allTests),
      testCase(EventSource_ToFutureTests.allTests),
      testCase(EventSource_TransformTests.allTests),
      testCase(EventSource_Zip2Tests.allTests),
      testCase(ExecutionContextTests.allTests),
      testCase(ExecutorTests.allTests),
      testCase(FallibleTests.allTests),
      testCase(Future_MakersTests.allTests),
      testCase(FutureTests.allTests),
      // these tests take too much time and do not give enough feedback
      // testCase(PerformanceTests.allTests),
      testCase(ReleasePoolTests.allTests),
      testCase(TimerChannelTests.allTests),
      testCase(ZipFuturesTest.allTests),
    ]
  }
#endif
