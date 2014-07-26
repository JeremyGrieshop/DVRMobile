
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

@interface CacheEntry : NSObject
{
@public
  id value;
  NSString *lastAccess;
}
@end

@interface Cache : NSObject
{
}
-(void)initialize;
-(id)getEntry: (id)key;
-(void)addEntry: (id)key withValue:(id)value;
@end
