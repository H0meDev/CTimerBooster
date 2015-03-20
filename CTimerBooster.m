//
//  CTimerBooster.m
//  NetworkSDK
//
//  Created by Cailiang on 14-9-20.
//  Copyright (c) 2014年 Cailiang. All rights reserved.
//

#import "CTimerBooster.h"
#import <objc/message.h>

#define CTimerBoosterTicker @"CTimerBoosterTicker"

#pragma mark - CTimerBoosterItem class

@interface CTimerBoosterItem : NSObject

@property (nonatomic, assign) NSTimeInterval executeTime;
@property (nonatomic, assign) NSTimeInterval timeInterval;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) id parameters;
@property (nonatomic, assign) BOOL repeat;

- (id)init;
- (BOOL)execute;

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

- (BOOL)execute
{
    if (self.target && [self.target respondsToSelector:self.selector]) {
        IMP imp = [self.target methodForSelector:self.selector];
        void (*execute)(id, SEL, id) = (void *)imp;
        execute(self.target, self.selector, self.parameters);
        
        return YES;
    }
    
    return NO;
}

- (void)dealloc
{
    self.target = nil;
    self.selector = nil;
    self.parameters = nil;
    self.repeat = NO;
    self.executeTime = 0;
    self.timeInterval = 0;
}

@end

#pragma mark - CTimerBooster class

static CTimerBooster *sharedManager = nil;

@interface CTimerBooster ()
{
    NSLock  *_managerLock;
}

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray *itemArray;

- (void)addTarget:(id)target
              sel:(SEL)selector
            param:(id)parameters
             time:(NSTimeInterval)time
           repeat:(BOOL)repeat;
- (void)remove:(id)target sel:(SEL)selector;
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
        _managerLock = [[NSLock alloc]init];
        
        // Add execute notification
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(executeWith:) name:CTimerBoosterTicker object:nil];
        
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
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.001f
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
    NSString *value = [NSString stringWithFormat:@"%.2lf", [[NSDate date]timeIntervalSince1970]];
    return [value doubleValue];
}

- (void)timeCounter
{
    static NSOperationQueue *queue = nil;
    if (queue == nil) {
        queue = [[NSOperationQueue alloc]init];
        queue.maxConcurrentOperationCount = 1000;
    }
    
    if (self.itemArray && self.itemArray.count > 0) {
        for (int i = 0; i < self.itemArray.count; i ++) {
            CTimerBoosterItem *item = self.itemArray[i];
            NSTimeInterval timeInterval = [self timeInterval];
            if (item.executeTime <= timeInterval) {
                // Make sure this will be executed
                [[NSNotificationCenter defaultCenter]postNotificationName:CTimerBoosterTicker object:item];
            }
        }
    }
}

- (void)executeWith:(NSNotification *)notification
{
    CTimerBoosterItem *item = (CTimerBoosterItem *)notification.object;
    if (![item execute] || !item.repeat) {
        // Remove the item that no need to be executed
        [self remove:item.target sel:item.selector];
        item = nil;
    } else {
        item.executeTime += item.timeInterval;
    }
}

- (void)addTarget:(id)target
              sel:(SEL)selector
            param:(id)parameters
             time:(NSTimeInterval)time
           repeat:(BOOL)repeat
{
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
- (void)remove:(id)target sel:(SEL)selector
{
    [self lock];
    
    for (int i = 0; i < self.itemArray.count; i ++) {
        // Remove the item
        CTimerBoosterItem *item = self.itemArray[i];
        NSString *className = NSStringFromClass([target class]);
        NSString *_className = NSStringFromClass([item.target class]);
        
        NSString *selName = NSStringFromSelector(selector);
        NSString *_selName = NSStringFromSelector(item.selector);
        
        if ((item.target == target) &&
            [className isEqualToString:_className] &&
            (item.selector == selector) &&
            [selName isEqualToString:_selName])
        {
            [self.itemArray removeObject:item];
            
            item.target = nil;
            item.selector = nil;
            item.parameters = nil;
            item.repeat = NO;
            item.executeTime = 0;
            item.timeInterval = 0;
            item = nil;
            
            break;
        }
    }

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
    
    [[NSNotificationCenter defaultCenter]removeObserver:self name:CTimerBoosterTicker object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    
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
    [[self sharedManager]remove:target sel:selector];
}

// 关闭发生器
+ (void)kill
{
    [self kill];
}

@end
