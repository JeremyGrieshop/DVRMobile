
#import "Cache.h"

@implementation CacheEntry
{

}
@end

@implementation Cache
{
}

-(void)initialize
{
}

-(id)getEntry: (id)key 
{
  return nil;
}

-(void)addEntry: (id)key withValue:(id)value
{
  CacheEntry *entry = [CacheEntry alloc];
  entry->value = value;
  entry->lastAccess = nil;


}
@end 

