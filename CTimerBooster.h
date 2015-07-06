//
//  CTimerBooster.h
//  UniversalApp
//
//  Created by Cailiang on 14-9-20.
//  Copyright (c) 2014年 Cailiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CTimerBooster : NSObject

// 开始频率Timer计时
+ (void)start;

// 添加一个接收目标, 不重复执行
+ (void)addTarget:(id)target sel:(SEL)selector time:(NSTimeInterval)time;

// 添加一个接收目标
+ (void)addTarget:(id)target sel:(SEL)selector time:(NSTimeInterval)time repeat:(BOOL)repeat;

// 添加一个带参接收目标
+ (void)addTarget:(id)target sel:(SEL)selector param:(id)parameters time:(NSTimeInterval)time;

// 添加一个带参接收目标
+ (void)addTarget:(id)target
              sel:(SEL)selector
            param:(id)parameters
             time:(NSTimeInterval)time
           repeat:(BOOL)repeat;

// 移除一个接收目标
+ (void)removeTarget:(id)target sel:(SEL)selector;

// 移除所有指定目标
+ (void)removeAllWithTarget:(id)target sel:(SEL)selector;

// 关闭发生器
+ (void)kill;

@end
