
#import <Foundation/Foundation.h>

@interface Composition : NSObject

- (void)create:(void (^)(NSURL *url))handler;

@end
