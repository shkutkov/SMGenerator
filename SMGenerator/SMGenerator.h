//
//  SMGenerator.h
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

#define SM_GENERATOR_WITH_ARGS_AS_ARRAY(TYPE, BLOCK, ARGS) \
    ^{ \
        SMGenerator *instance = [[SMGenerator alloc] initWithType:TYPE]; \
        __weak typeof(instance) weakInstance = instance; \
        [weakInstance setGeneratorBlock:BLOCK withArguments:ARGS];\
        return instance; \
    }()

#define SM_ARGS_TO_ARRAY(...) @[ __VA_ARGS__ ]
#define SM_GENERATOR_WITH_TYPE(TYPE, BLOCK, ...) SM_GENERATOR_WITH_ARGS_AS_ARRAY(TYPE, BLOCK, SM_ARGS_TO_ARRAY( __VA_ARGS__ ))

#define SM_SYNC_GENERATOR(BLOCK, ...)  SM_GENERATOR_WITH_TYPE(kSMGeneratorSynchronousType, BLOCK, __VA_ARGS__ )
#define SM_ASYNC_GENERATOR(BLOCK, ...) SM_GENERATOR_WITH_TYPE(kSMGeneratorAsynchronousType, BLOCK, __VA_ARGS__ )

#define SM_GENERATOR(...) SM_SYNC_GENERATOR(  __VA_ARGS__ )

#define SM_YIELD(OBJ) \
    do { \
        SMGeneratorYieldBlock block = [weakInstance yieldBlock]; \
        if (block == nil || !(block(OBJ))) { \
            return; \
        } \
    } while (0)


typedef BOOL(^SMGeneratorYieldBlock)(id);

typedef NS_ENUM(NSInteger, SMGeneratorCalculationType) {
    kSMGeneratorSynchronousType,
    kSMGeneratorAsynchronousType
};

@interface SMGenerator : NSObject<NSFastEnumeration>


/*!
 * @method initWithType
 *
 * @abstract
 * SMGenerator instance initializer
 *
 * @discussion
 * Do not use this method directly, for generator creation use
 * preprocessor directives SM_GENERATOR or SM_ASYNC_GENERATOR
 *
 * @result
 * SMGenerator instance
 */
- (instancetype)initWithType:(SMGeneratorCalculationType)type;

/*!
 * @method setGeneratorBlock
 *
 * @abstract
 * Internal method for setting generator parameters
 *
 * @discussion
 * Do not use this method directly, for generator creation use
 * preprocessor directives SM_GENERATOR or SM_ASYNC_GENERATOR
 */
- (void)setGeneratorBlock:(id)block withArguments:(NSArray *)arguments;

/*!
 * @method yieldBlock
 *
 * @abstract
 * Internal method for processing generator result
 *
 * @discussion
 * Do not use it directly.
 * To yield object use preprocessor directive SM_YIELD
 *
 * @result
 * Internal block for result processing
 */
- (SMGeneratorYieldBlock)yieldBlock;

/*!
 * @method next
 *
 * @abstract
 * Produces next generator value
 *
 * @discussion
 * This method waits while generator block produced next value
 * If generator is finished, then method returns nil
 *
 * @result
 * Next generated object or nil
 */
- (id)next;

@end
