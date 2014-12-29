//
//  CTimerBooster.h
//  NetworkSDK
//
//  Created by Cailiang on 14-9-20.
//  Copyright (c) 2014年 Cailiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CTimerBooster : NSObject

// 开始频率Timer计时,以0.001s发生一次
+ (void)start;

// 添加一个接收目标
+ (void)addTarget:(id)target sel:(SEL)selector time:(NSUInteger)time;

// 移除一个接收目标
+ (void)removeTarget:(id)target sel:(SEL)selector;

// 关闭发生器
+ (void)kill;

@end
