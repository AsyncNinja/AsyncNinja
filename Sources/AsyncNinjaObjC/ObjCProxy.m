//
//  ObjCProxy.m
//  AsyncNinja
//
//  Created by Anton Mironov on 12/30/16.
//
//

#import <Foundation/Foundation.h>
#include "include/ObjCProxy.h"

void asyncNinjaRemoveObserver(void *from, NSObject *observer, NSString *keyPath) {
  [(__bridge id)from removeObserver:observer forKeyPath:keyPath];
}
