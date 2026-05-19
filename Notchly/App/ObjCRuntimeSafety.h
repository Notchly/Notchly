#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCRuntimeSafety : NSObject

+ (nullable id)valueForKey:(NSString *)key fromObject:(id)object;

@end

NS_ASSUME_NONNULL_END
