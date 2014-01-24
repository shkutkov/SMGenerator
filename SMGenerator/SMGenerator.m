//
//  SMGenerator.m
//  SMGenerator
//
//  Created by Mikhail Shkutkov on 21/01/14.
//  Copyright (c) 2014 Mikhail Shkutkov, http://www.shkutkov.com
//
//  MIT LICENSE
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "SMGenerator.h"

typedef void(^BlockWith0Arguments)();
typedef void(^BlockWith1Arguments)(id);
typedef void(^BlockWith2Arguments)(id, id);
typedef void(^BlockWith3Arguments)(id, id, id);
typedef void(^BlockWith4Arguments)(id, id, id, id);
typedef void(^BlockWith5Arguments)(id, id, id, id, id);
typedef void(^BlockWith6Arguments)(id, id, id, id, id, id);
typedef void(^BlockWith7Arguments)(id, id, id, id, id, id, id);
typedef void(^BlockWith8Arguments)(id, id, id, id, id, id, id, id);
typedef void(^BlockWith9Arguments)(id, id, id, id, id, id, id, id, id);
typedef void(^BlockWith10Arguments)(id, id, id, id, id, id, id, id, id, id);

#define CALL_BLOCK_WITH_ARGUMENTS(count, block, arguments) \
     ((BlockWith##count##Arguments)block)(ARGS_##count(arguments))

#define ARGS_10(args) ARGS_9(args), args[9]
#define ARGS_9(args)  ARGS_8(args), args[8]
#define ARGS_8(args)  ARGS_7(args), args[7]
#define ARGS_7(args)  ARGS_6(args), args[6]
#define ARGS_6(args)  ARGS_5(args), args[5]
#define ARGS_5(args)  ARGS_4(args), args[4]
#define ARGS_4(args)  ARGS_3(args), args[3]
#define ARGS_3(args)  ARGS_2(args), args[2]
#define ARGS_2(args)  ARGS_1(args), args[1]
#define ARGS_1(args)  args[0]
#define ARGS_0(args)

@interface SMGenerator()

@property (nonatomic, assign) SMGeneratorCalculationType type;
@property (nonatomic, assign) BOOL started;

@property (nonatomic, strong) id generatorBlock;
@property (nonatomic, strong) NSArray *arguments;

@property (nonatomic, strong) NSObject *result;

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_semaphore_t semaphoreGenerationContinue;
@property (nonatomic, strong) dispatch_semaphore_t semaphoreHasResult;

@property (nonatomic, strong) SMGeneratorYieldBlock yieldBlock;

@end

@implementation SMGenerator

- (instancetype)initWithType:(SMGeneratorCalculationType)type
{
    self = [super init];
    if (self) {
        _type       = type;
        _started    = NO;
        _yieldBlock = nil;
        _queue      = dispatch_queue_create([[NSString stringWithFormat:@"SMGeneratorQueue%p", (__bridge void *)self] UTF8String], NULL);
        
        _semaphoreGenerationContinue = dispatch_semaphore_create(0);
        _semaphoreHasResult          = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)dealloc
{
    [self cleanUp];
}

- (void)setGeneratorBlock:(id)block withArguments:(NSArray *)arguments
{
    //TODO: check that arguments of block matche to passed arguments
    self.generatorBlock = block;
    self.arguments      = arguments;
}

- (id)next
{
    if (self.queue == nil) {
        return nil;
    }
    
    self.result = nil;

    dispatch_semaphore_t hasResult          = _semaphoreHasResult;
    dispatch_semaphore_t generationContinue = _semaphoreGenerationContinue;

    if (self.type == kSMGeneratorSynchronousType) {
        if (!self.started) {
            [self startBlockAsynchroniously];
        } else {
            dispatch_semaphore_signal(generationContinue);
        }
        
        dispatch_semaphore_wait(hasResult, DISPATCH_TIME_FOREVER);
    } else {
        if (!self.started) {
            [self startBlockAsynchroniously];
        }
        dispatch_semaphore_signal(generationContinue);
        dispatch_semaphore_wait(hasResult, DISPATCH_TIME_FOREVER);
    }

    if (self.result == nil) {
        [self cleanUp];
    }

    return self.result;
}

#pragma mark - Private methods

- (void)cleanUp
{
    _queue = nil;
    _arguments = nil;
    _generatorBlock = nil;
    
    dispatch_semaphore_signal(_semaphoreGenerationContinue);
}

- (void)startBlockAsynchroniously
{
    self.started = YES;
    
    __weak __typeof(self) weakSelf = self;
    
    SMGeneratorCalculationType type = self.type;
    dispatch_semaphore_t hasResult = self.semaphoreHasResult;
    dispatch_semaphore_t generationContinue = self.semaphoreGenerationContinue;
    
    self.yieldBlock = ^(id result) {
        if (type == kSMGeneratorAsynchronousType) {
            dispatch_semaphore_wait(generationContinue, DISPATCH_TIME_FOREVER);
        }
        
        [weakSelf setResult:result];
        
        if (type == kSMGeneratorSynchronousType) {
            dispatch_semaphore_signal(hasResult);
            dispatch_semaphore_wait(generationContinue, DISPATCH_TIME_FOREVER);
        } else {
            dispatch_semaphore_signal(hasResult);
        }
        
        return (BOOL)([weakSelf queue] != nil);
    };
    
    id generatorBlock = self.generatorBlock;
    NSArray *args     = self.arguments;
    
    dispatch_async(_queue, ^{
        switch ([args count]) {
            case 0:  CALL_BLOCK_WITH_ARGUMENTS(0,  generatorBlock, args); break;
            case 1:  CALL_BLOCK_WITH_ARGUMENTS(1,  generatorBlock, args); break;
            case 2:  CALL_BLOCK_WITH_ARGUMENTS(2,  generatorBlock, args); break;
            case 3:  CALL_BLOCK_WITH_ARGUMENTS(3,  generatorBlock, args); break;
            case 4:  CALL_BLOCK_WITH_ARGUMENTS(4,  generatorBlock, args); break;
            case 5:  CALL_BLOCK_WITH_ARGUMENTS(5,  generatorBlock, args); break;
            case 6:  CALL_BLOCK_WITH_ARGUMENTS(6,  generatorBlock, args); break;
            case 7:  CALL_BLOCK_WITH_ARGUMENTS(7,  generatorBlock, args); break;
            case 8:  CALL_BLOCK_WITH_ARGUMENTS(8,  generatorBlock, args); break;
            case 9:  CALL_BLOCK_WITH_ARGUMENTS(9,  generatorBlock, args); break;
            case 10: CALL_BLOCK_WITH_ARGUMENTS(10, generatorBlock, args); break;
            default: [NSException raise:@"Too many arguments"
                                 format:@"SMGenerator doesn't support more than 10 arguments"];
        }
        
        dispatch_semaphore_signal(hasResult);
    });
}

#pragma mark - NSFastEnumeration protocol

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    if(state->state == 0) {
        state->mutationsPtr = &state->extra[0];
        state->state = 1;
    }
    id obj = [self next];
    if (obj == nil) {
        return 0;
    } else {
        state->itemsPtr = buffer;
        buffer[0] = obj;
        return 1;
    }
}

@end
