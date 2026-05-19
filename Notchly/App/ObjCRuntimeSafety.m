#import "ObjCRuntimeSafety.h"

@implementation ObjCRuntimeSafety

+ (nullable id)valueForKey:(NSString *)key fromObject:(id)object {
    @try {
        return [object valueForKey:key];
    } @catch (NSException *exception) {
        return nil;
    }
}

@end
