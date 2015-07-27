//
//  CTimerBooster.m
//  UniversalApp
//
//  Created by Cailiang on 14-9-20.
//  Copyright (c) 2014年 Cailiang. All rights reserved.
//

#import "CTimerBooster.h"
#import <objc/message.h>

#pragma mark - CTimerBoosterItem class

@interface CTimerBoosterItem : NSObject

@property (nonatomic, assign) NSTimeInterval executeTime;
@property (nonatomic, assign) NSTimeInterval timeInterval;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) id parameters;
@property (nonatomic, assign) BOOL repeat;

- (id)init;
- (void)execute;

@end

@implementation CTimerBoosterItem

- (id)init
{
    self = [super init];
    if (self) {
        self.executeTime = 0;
        self.target = nil;
        self.selector = nil;
        self.parameters = nil;
        self.repeat = NO;
    }
    
    return self;
}

- (void)execute
{
    if (self.target && self.selector && [self.target respondsToSelector:self.selector]) {
        IMP imp = [self.target methodForSelector:self.selector];
        if (imp) {
            void (*execute)(id, SEL, id) = (void *)imp;
            execute(self.target, self.selector, self.parameters);
        }
    }
}

- (void)dealloc
{
    NSLog(@"CTimerBoosterItem dealloc.");
}

@end

#pragma mark - CTimerBooster class

static CTimerBooster *sharedManager = nil;

@interface CTimerBooster ()
{
    NSLock  *_managerLock;
    NSDateFormatter *_formatter;
    dispatch_queue_t _excuteQueue;
}

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray *itemArray;

- (void)addTarget:(id)target sel:(SEL)selector param:(id)parameters time:(NSTimeInterval)time repeat:(BOOL)repeat;
- (void)remove:(id)target sel:(SEL)selector all:(BOOL)removeAll;
- (void)kill;

@end

@implementation CTimerBooster

+ (id)sharedManager
{
    @synchronized (self)
    {
        if (sharedManager == nil) {
            return [[self alloc] init];
        }
    }
    
    return sharedManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized (self) {
        if (sharedManager == nil) {
            return [super allocWithZone:zone];
        }
    }
    
    return nil;
}

- (id)init
{
    @synchronized(self) {
        self = [super init];
        // Initialize
        sharedManager = self;
        _excuteQueue = dispatch_queue_create("CTimerBoosterQueue", DISPATCH_QUEUE_CONCURRENT);
        _managerLock = [[NSLock alloc]init];
        
        // Keep time interval same
        NSTimeZone *zone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
        _formatter = [[NSDateFormatter alloc]init];
        [_formatter setTimeZone:zone];
        [_formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
        return self;
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

#pragma mark - Properties

- (NSTimer *)timer
{
    if (_timer) {
        return _timer;
    }
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1f
                                              target:self
                                            selector:@selector(timeCounter)
                                            userInfo:nil
                                             repeats:YES];
    [[NSRunLoop currentRunLoop]addTimer:_timer forMode:NSRunLoopCommonModes];
    
    return _timer;
}

- (NSMutableArray *)itemArray
{
    if (_itemArray) {
        return _itemArray;
    }
    
    _itemArray = [NSMutableArray array];
    
    return _itemArray;
}

#pragma mark - Self Methods

- (void)lock
{
    [_managerLock lock];
}

- (void)unlock
{
    [_managerLock unlock];
}

- (NSTimeInterval)timeInterval
{
    @autoreleasepool
    {
        NSDate *date = [NSDate date];
        NSString *timestamp = [_formatter stringFromDate:date];
        NSTimeInterval time = [[_formatter dateFromString:timestamp]timeIntervalSince1970];
        
        return [[NSString stringWithFormat:@"%.2lf", time] doubleValue];
    }
}

- (void)timeCounter
{
    [self lock];
    
    NSArray *itemArray = [NSArray arrayWithArray:self.itemArray];
    
    [self unlock];
    
    if (itemArray && itemArray.count > 0) {
        // Get current time interval
        NSTimeInterval timeInterval = [self timeInterval];
        
        // Excute
        for (int i = 0; i < itemArray.count; i ++) {
            CTimerBoosterItem *item = itemArray[i];
            if (item.executeTime <= timeInterval) {
                item.executeTime = timeInterval;
                
                // Make sure this will be executed
                dispatch_async(_excuteQueue, ^{
                    [self executeWith:item];
                });
            }
        }
    }
}

- (void)executeWith:(CTimerBoosterItem *)item
{
    // Execute the method
    [item execute];
    
    if (!item.repeat) {
        // Remove the item that no need to be executed
        [self remove:item.target sel:item.selector all:NO];
        item = nil;
    } else {
        item.executeTime += item.timeInterval;
    }
}

- (void)addTarget:(id)target sel:(SEL)selector param:(id)parameters time:(NSTimeInterval)time repeat:(BOOL)repeat
{
    // No more than 20 tasks running at the same time.
    if (self.itemArray.count > 20) {
        return;
    }
    
    [self lock];
    
    // 控制精度
    NSString *value = [NSString stringWithFormat:@"%.2lf", time];
    time = [value floatValue];
    
    CTimerBoosterItem *item = [[CTimerBoosterItem alloc]init];
    item.target = target;
    item.selector = selector;
    item.parameters = parameters;
    item.timeInterval = time;
    item.executeTime = [self timeInterval] + time;
    item.repeat = repeat;
    
    [self.itemArray addObject:item];
    [self unlock];
}

// 移除一个接收目标
- (void)remove:(id)target sel:(SEL)selector all:(BOOL)removeAll
{
    [self lock];
    
    NSMutableArray *itemArray = [NSMutableArray arrayWithArray:self.itemArray];
    for (int i = 0; i < itemArray.count; i ++) {
        // Remove the item
        CTimerBoosterItem *item = itemArray[i];
        NSString *className = NSStringFromClass([target class]);
        NSString *_className = NSStringFromClass([item.target class]);
        
        NSString *selName = NSStringFromSelector(selector);
        NSString *_selName = NSStringFromSelector(item.selector);
        
        if (item.target == nil || ((item.target == target) &&
            [className isEqualToString:_className] &&
            (item.selector == selector) &&
            [selName isEqualToString:_selName]))
        {
            [itemArray removeObject:item];
            
            if (!removeAll) {
                break;
            }
        }
    }
    
    self.itemArray = itemArray;
    
    [self unlock];
}

// 关闭
- (void)kill
{
    [self lock];
    
    [self.timer invalidate];
    self.timer = nil;
    
    [self.itemArray removeAllObjects];
    self.itemArray = nil;
    
    [self unlock];
}

// 开始频率Timer计时
+ (void)start
{
    [[self sharedManager]timer];
}

// 添加一个接收目标, 不重复执行
+ (void)addTarget:(id)target sel:(SEL)selector time:(NSTimeInterval)time
{
    [[self sharedManager]addTarget:target sel:selector param:nil time:time repeat:NO];
}

// 添加一个接收目标
+ (void)addTarget:(id)target sel:(SEL)selector time:(NSTimeInterval)time repeat:(BOOL)repeat
{
    [[self sharedManager]addTarget:target sel:selector param:nil time:time repeat:repeat];
}

// 添加一个带参接收目标, 不重复执行
+ (void)addTarget:(id)target sel:(SEL)selector param:(id)parameters time:(NSTimeInterval)time
{
    [[self sharedManager]addTarget:target sel:selector param:parameters time:time repeat:NO];
}

// 添加一个带参接收目标
+ (void)addTarget:(id)target
              sel:(SEL)selector
            param:(id)parameters
             time:(NSTimeInterval)time
           repeat:(BOOL)repeat
{
    [[self sharedManager]addTarget:target sel:selector param:parameters time:time repeat:repeat];
}

// 移除一个接收目标
+ (void)removeTarget:(id)target sel:(SEL)selector
{
    [[self sharedManager]remove:target sel:selector all:NO];
}

+ (void)removeAllWithTarget:(id)target sel:(SEL)selector
{
    [[self sharedManager]remove:target sel:selector all:YES];
}

// 关闭发生器
+ (void)kill
{
    [self kill];
}

@end
