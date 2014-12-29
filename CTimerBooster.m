//
//  CTimerBooster.m
//  NetworkSDK
//
//  Created by Cailiang on 14-9-20.
//  Copyright (c) 2014年 Cailiang. All rights reserved.
//

#import "CTimerBooster.h"
#import <objc/message.h>

@interface NSTimerBoosterTarget : NSObject

@property (nonatomic, assign) NSUInteger time;
@property (nonatomic, assign) NSUInteger tick;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;

- (id)init;
- (void)run;

@end

@implementation NSTimerBoosterTarget

- (id)init
{
    self = [super init];
    if (self) {
        self.time = 0;
        self.tick = 0;
        self.target = nil;
        self.selector = nil;
    }
    return self;
}

- (void)run
{
    if (self.target && [self.target respondsToSelector:self.selector]) {
        IMP imp = [self.target methodForSelector:self.selector];
        void (*excute)(id, SEL) = (void *)imp;
        excute(self.target, self.selector);
    }
}

@end

static CTimerBooster *sharedManager = nil;

@interface CTimerBooster ()
{
    NSLock  *managerLock;
    NSMutableArray *targets;
}

@property (nonatomic, strong) NSTimer *timer;

- (void)add:(id)target sel:(SEL)selector time:(NSUInteger)time;
- (void)remove:(id)target sel:(SEL)selector;
- (void)kill;

@end

@implementation CTimerBooster

+ (id)sharedManager
{
    @synchronized (self)
    {
        if (sharedManager == nil) {
            sharedManager = [[self alloc] init];
        }
    }
    return sharedManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized (self) {
        if (sharedManager == nil) {
            sharedManager = [super allocWithZone:zone];
            return sharedManager;
        }
    }
    return nil;
}

- (id)init
{
    @synchronized(self) {
        self = [super init];
        // Init
        managerLock = [[NSLock alloc]init];
        
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
                                            selector:@selector(timerMaker)
                                            userInfo:nil
                                             repeats:YES];
    [[NSRunLoop currentRunLoop]addTimer:_timer forMode:NSRunLoopCommonModes];
    return _timer;
}

#pragma mark - Self Methods

- (void)lock
{
    [managerLock lock];
}

- (void)unlock
{
    [managerLock unlock];
}

- (void)timerMaker
{
    [self lock];
    
    static NSOperationQueue *queue = nil;
    if (queue == nil) {
        queue = [[NSOperationQueue alloc]init];
        queue.maxConcurrentOperationCount = 1000;
    }
    
    if (targets && targets.count > 0) {
        for (NSTimerBoosterTarget *target in targets) {
            target.tick ++;
            if (target.time == target.tick) {
                target.tick = 0;
                NSInvocationOperation *operation = [NSInvocationOperation alloc];
                operation = [operation initWithTarget:self selector:@selector(runWithTarget:) object:target];
                [queue addOperation:operation];
                operation = nil;
            }
        }
    }
    
    [self unlock];
}

- (void)runWithTarget:(NSTimerBoosterTarget *)target
{
    [target run];
}

- (void)add:(id)target sel:(SEL)selector time:(NSUInteger)time
{
    [self lock];
    
    if (!targets) {
        targets = [NSMutableArray array];
    }
    
    for (int i = 0; i < targets.count; i ++) {
        // 移除Selector
        NSTimerBoosterTarget *ftg = targets[i];
        NSString *className = NSStringFromClass([target class]);
        NSString *selName = NSStringFromSelector(ftg.selector);
        NSString *_selName = NSStringFromSelector(selector);
        NSString *_className = NSStringFromClass([ftg.target class]);
        
        if ([className isEqualToString:_className] && ftg.target == target && [_selName isEqualToString:selName]) {
            NSLog(@"NSTimerBoosterTarget [%@, %@] ALREADY ADDED",className, selName);
            [self unlock];
            return;
        }
    }
    
    NSTimerBoosterTarget *ftarget = [[NSTimerBoosterTarget alloc]init];
    ftarget.target = target;
    ftarget.selector = selector;
    ftarget.time = time;
    [targets addObject:ftarget];
    
    [self unlock];
}

// 移除一个接收目标
- (void)remove:(id)target sel:(SEL)selector
{
    [self lock];
    
    for (int i = 0; i < targets.count; i ++) {
        // 移除Selector
        NSTimerBoosterTarget *ftg = targets[i];
        NSString *className = NSStringFromClass([target class]);
        NSString *selName = NSStringFromSelector(ftg.selector);
        NSString *_selName = NSStringFromSelector(selector);
        NSString *_className = NSStringFromClass([ftg.target class]);
        
        if ([className isEqualToString:_className] && ftg.target == target && [_selName isEqualToString:selName]) {
            ftg.target = nil;
            ftg.selector = nil;
            ftg.time = 0;
            ftg.tick = 0;
            [targets removeObject:ftg];
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
    
    [targets removeAllObjects];
    targets = nil;
    
    [self unlock];
}

// 开始频率Timer计时,以0.001s发生一次
+ (void)start
{
    [[self sharedManager]timer];
}

// 添加一个接收目标
+ (void)addTarget:(id)target sel:(SEL)selector time:(NSUInteger)time
{
    [[self sharedManager]add:target sel:selector time:time];
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
