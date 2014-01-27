# SMGenerator: experimental fast and easy way to create generators in Objective-C

## Overview

As you might know Objecteve-C doesn't support [generators](http://en.wikipedia.org/wiki/Generator_(computer_science%29) natively, but they may be useful to express some ideas. For example Python has such support and sometimes they are used [very intensively](http://www.dabeaz.com/generators/). The simplest generator that make any sense in Python looks like this:

```python
def countfrom(n):
    while True:
        yield n
        n += 1
```
        
yield statement is similar to return in regular function. The difference is that generator state is saved and on the next call it will be restored and execution will continue (rather that started at the the top as in regular functions).

Mike Ash in his wonderful blog a long time ago [discussed this topic](https://mikeash.com/pyblog/friday-qa-2009-10-30-generators-in-objective-c.html). He suggested [a solution for creating generators in Objective-C](https://github.com/mikeash/MAGenerator). Similar technic was used in [EXTCoroutine](https://github.com/jspahrsummers/libextobjc/blob/master/extobjc/EXTCoroutine.h) from [libextobjc](https://github.com/jspahrsummers/libextobjc).

SMGenerator suggests another approach of generator creation in Objective-C. Let's dive in more details and discuss pros and cons of this method.

## Idea

The main idea behind generators that they save their states on "return". What if we start our function in another thread and just stop execution when code yield some result. Before stopping we pass that result value to the original thread which will be returned by generator. On the next execution we just resume thread and function continue its evaluation. The idea is a pretty simple, let's look how generator will look like.

## Basic implementation

The main goal of SMGenerator is simplicity in creation and usage. Generators are usually used in loops, so it would be cool if we can write something like this:

```objc
for (NSObject *object in generator) {
    //...
}
```

And using SMGenerator you can do this, because it adopts NSFastEnumeration protocol. The simplest generator that make any sense in Objective-C using SMGenerator will be:

```objc
SM_GENERATOR(^(NSNumber *n) {
    while (TRUE) {
        SM_YIELD(n);
        n = @([n intValue] + 1);
    }
}, (@1));
```

SM_GENERATOR and SM_YIELD are macroses, that allow us to write less code. SM_GENERATOR takes at least one argument - block, that yields values using SM_YIELD. If block takes arguments, you can pass them into SM_GENERATOR as second, third, etc. arguments. 

You can use generator in two ways:

#### In for/in loops

Like that:

```objc
SMGenerator *generator = SM_GENERATOR(^(NSNumber *n) {
    while (TRUE) {
        SM_YIELD(n);
        n = @([n intValue] + 1);
    }
}, (@1));
 
for (NSNumber *num in generator) {
    NSLog(@"Number %@", num);
}
```

Or it's even possible to avoid local variable if necessary:

```objc
for (NSNumber *num in SM_GENERATOR(^(NSNumber *n) {
    while (TRUE) {
        SM_YIELD(n);
        n = @([n intValue] + 1);
    }
}, (@1))) {
    NSLog(@"Number %@", num);
}
```

#### Manually by sending "next" message to generator

SMGenerator has a next method:

```objc
/*!
 * @method next
 *
 * @abstract
 * Produces next value
 *
 * @discussion
 * This method waits while next value will be procesed by external block
 * If external block is ended, this method returns nil
 *
 * @result
 * Next generated value or nil
 */
- (id)next;
```

Thus it's possible to get values simply sending *next* message to generator, like this:

```objc
NSLog(@"Number 1 %@", [generator next]);
NSLog(@"Number 2 %@", [generator next]);
NSLog(@"Number 3 %@", [generator next]);
```

By the way it's not a problem to have more than one SM_YIELD statement in user block.

```objc
SMGenerator *generator = SM_GENERATOR(^{
    while (TRUE) {
        SM_YIELD(@"one");
        SM_YIELD(@"two");
        SM_YIELD(@"three");
    }
});
```

#### More technical details

SMGenerator uses [GCD](http://en.wikipedia.org/wiki/Grand_Central_Dispatch) to run user block on its own queue. Thus this block works in another thread and synchornization with the orignal one (not only main thread, it maybe any thread that created your generator) are achived using semaphores. Actually user block works only when the orignal thread is blocked:

1. We ask SMGenerator to get new value (e.g. senging next message to instance)
1. SMGenerator resumes user block and waits for result
1. User block starts working in the another thread and when result is ready it notify SMGenerator and stop its execution
1. SMGenerator receives new value and returns it to original thread

With this approach it's safely to modify objects and variables from outer scope. For example, it's ok to rewrite our "the simplest generator that make any sense" like this:

```objc
__block NSNumber *n = @(1);
SMGenerator *generator = SM_GENERATOR(^{
    while (TRUE) {
        SM_YIELD(n);
        n = @([n intValue] + 1);
    }
});
```

#### One big step forward

Probably, after reading previous section you said: "Stop, but what if we calculate next value in asynchronous manner, so when we ask generator about next value it simply returns already producessed one". And this is reasonable remark. Acutally you can do it with SMGenerator! Just use SM_ASYNC_GENERATOR instead of SM_GENERATOR. This might be really big step fordard in terms of performance for heavy generators. Our previous example rewritten in asynchronous manner looks like:

```objc
SM_ASYNC_GENERATOR(^(NSNumber *n) {
    while (TRUE) {
        SM_YIELD(n);
        n = @([n intValue] + 1);
    }
}, (@1));
```

But you should be careful with SM_ASYNC_GENERATOR, because of its asynchronism. Using __block variables or modify external object inside SM_ASYNC_GENERATOR is a potentially dangerous! 

## Caviets and limitations

It's normal that implementation of any idea has its own caviets. So let's highlight ones of SMGenerator

* User block cannot take primitive types as arguments, so use Objective-C objects (custom object, NSString, NSNumber, NSValue)
* It is possible to use return statement inside user block, but this stops generator (It will return nil values, if you send "next" message)
* If user block takes some arguments, they must be passed into SM_GENERATOR/SM_ASYNC_GENERATOR, otherwise you'll receive a runtime error. So don't forget about them.
* User block have to yield only Objective-C object. So use [Objective-c literals](http://clang.llvm.org/docs/ObjectiveCLiterals.html) if necessary.
* SMGenerator is based on GCD, thus it has limitations related with that. On iOS 6/7 you cannot have more that 512 **active** generators. It's a rather big number, but it worth to mention.
* In case of SM_ASYNC_GENERATOR be careful when modifing external object or using __block variables
* SMGenerator must be built with ARC and targeting either iOS 6.0 and above, or Mac OS 10.8 Mountain Lion and above.


## Syntax comparison of different generators

Let's compare the syntax that suggest us SMGenerator, MAGenerator and EXTCoroutine.

#### The simplest generator that make any sense

We've already seen how it looks like using SMGenerator, but let's repeat this code again:

```objc
SMGenerator *generator = SM_GENERATOR(^(NSNumber *n) {
    while (TRUE) {
        SM_YIELD(n);
        n = @([n intValue] + 1);
    }
}, (@42));
 
for (NSNumber *num in generator) {
    NSLog(@"Number %@", num);
}
```

The same result using MAGenerator looks like:

```objc
GENERATOR(int, CountFrom(int start), (void)) {
    __block int n;
    GENERATOR_BEGIN(void) {
        n = start;
        while(TRUE) {
            GENERATOR_YIELD(n);
            n++;
        }
    }
    GENERATOR_END
}
 
int (^counter)(void) = CountFrom(42);
for(int i = 0; i < 10; i++) {
    NSLog(@"Number %d", counter());
}
```

With EXTCoroutine:

```objc
__block int n;
int (^generator)(int) = coroutine(int from)({
    n = from;
    while(TRUE) {
        yield n;
        n++;
    }
});
 
for(int i = 0; i < 10; i++) {
    NSLog(@"%d", generator(42));
}
```

MAGenerator is a little bit verbose, in the same time EXTCoroutine is much simpler, but you should be really carefully with it, bacause if you write something like this it won't work as excepcted:

```objc
int (^generator)(int) = coroutine(int n)({
    while(TRUE) {
        yield n;
        n++;
    }
});
```

It will produces 42, 43, 43, 43, 43, 43, 43, 43, 43, 43, 43. Is it obvious? Guess not...

#### File finder at a certain path with a certain extension

SMGenerator:

```objc
SMGenerator *fileFinder = SM_GENERATOR(^(NSString *path, NSString *ext) {
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath: path];
    for (NSString *subpath in enumerator) {
        if([[subpath pathExtension] isEqualToString: ext]) {
            SM_YIELD((id)[path stringByAppendingPathComponent: subpath]);
        }
    }
}, @"/Applications", @"app");
 
for(NSString *path in fileFinder) {
    NSLog(@"%@", path);
}
```

MAGenerator:

```objc
GENERATOR(id, FileFinder(NSString *path, NSString *extension), (void))
{
    __block NSString *subpath;
    __block NSDirectoryEnumerator *enumerator;
    GENERATOR_BEGIN(void) {
        enumerator = [[NSFileManager defaultManager] enumeratorAtPath: path];
        for (subpath in enumerator) {
            if([[subpath pathExtension] isEqualToString: extension]) {
                GENERATOR_YIELD((id)[path stringByAppendingPathComponent: subpath]);
            }
        }
    }
    GENERATOR_END
}
 
 for(NSString *path in MAGeneratorEnumerator(FileFinder(@"/Applications", @"app"))) {
    NSLog(@"%@", path);
}
```

Finite generators that are implemented using coroutine from EXTCoroutine becomes infinite (they just start over again and again). So we need to write some more code to handle this nuance:

```objc
__block NSString *subpath;
__block NSDirectoryEnumerator *enumerator;
NSString * (^generator)(NSString *, NSString *) = coroutine(NSString *path, NSString *ext)({
    enumerator = [[NSFileManager defaultManager] enumeratorAtPath: path];
    for (subpath in enumerator) {
        if([[subpath pathExtension] isEqualToString: ext]) {
            yield [path stringByAppendingPathComponent: subpath];
        }
    }
    yield (NSString *)nil;
});
 
NSString *path;
do {
    path = generator(@"/Applications", @"app");
    if (path != nil) {
        NSLog(@"%@", path);
    }
} while (path != nil);
```

As you can see from these two examples, that SMGenerator suggest more robust and simple to use solution due to the new approach.

## Performance

What is the price of using SMGenerator?

Let's do some tests.

For each generator (synchronous and asynchronous SMGenerator, MAGenerator, EXTCoroutine) we run test 5 times on iPhone 5 and iOS Simulator, and than exclude the maximum and minumum value and calculate median. 

#### The simplest generator that make any sense

The code you can find in the previous section, so let's just simply generate some numbers from 1 to 100000 without any procesing.

|Generator Name| iOS Simulator | iPhone 5 |
|---------|---------:|---------:|
| Synchronous SMGenerator| 1.403748| 3.505760| 
| Asynchronous SMGenerator| 1.122638| 3.904675| 
| MAGenerator|0.063351|0.192528|
| EXTCoroutine|0.042789|0.133374|

As you can see SMGenerator both synchronous and asynchrous version are much slower (18-26 times slower on iOS Simulator and iPhone 5) than MAGenerator and EXTCoroutine.

Also interesting is that Asynchronous version of SMGenerator is faster than synchrounous one on iOS Simulator and slower on the real device.

Let's take the same generator and print 1000 values to the console. 

|Generator Name| iOS Simulator | iPhone 5 |
|---------|---------:|---------:|
| Synchronous SMGenerator | 0,935951 | 1,184753 | 
| Asynchronous SMGenerator | 0,974847 | 1,138995 | 
| MAGenerator | 0,950513 | 1,052925 |
| EXTCoroutine | 0,990335 | 1,055256 |

As you can see in this example there is almostly no difference between SMGenerator and other implementation. 

Let's look at the last example: print first 1000 prime nubers that are bigger than 100000 to console.

The code for calculating prime numbers will be rather inefficient, but it's not a big problem for our case - we just need a "heave" task in generator.

SMGenerator:
```objc
SM_GENERATOR(^(NSNumber *from) {
    for(NSInteger n = [from integerValue]; ; n++) {
        int i;
        for(i = 2; i < n; i++)
            if(n % i == 0)
                break;
        if(i == n) {
            SM_YIELD(@(n));
        }
    }
}, @(self.from));
```

Asynchronous version of this generator can be made just replacing SM_GENERATOR with SM_ASYNC_GENERATOR.

MAGernerator:

```objc
GENERATOR(NSNumber *, Primes(NSInteger from), (void))
{
    __block int n;
    __block int i;
    GENERATOR_BEGIN(void) {
        for(n = from; ; n++)  {
            for(i = 2; i < n; i++)
                if(n % i == 0)
                    break;
            if(i == n)
                GENERATOR_YIELD(@(n));
        }
    }
    GENERATOR_END
}
```

EXTCoroutine:

```objc
__block int n;
__block int i;
NSInteger from = 100000;
return coroutine()({
    for(n = from; ; n++) {
        for(i = 2; i < n; i++)
            if(n % i == 0)
                break;
        if(i == n) {
            ext_yield @(n);
        }
    }
});
```

|Generator Name| iOS Simulator | iPhone 5 |
|---------|---------:|---------:|
| Synchronous SMGenerator | 1,038034 | 3,519533 | 
| Asynchronous SMGenerator | 0,747974| 2,448181 | 
| MAGenerator | 1,041472 | 3,776557 |
| EXTCoroutine | 1,029701 | 3,775673 |

In this example we simulate the case when value generation takes some time and there is a processing. As you can see asynchronous version of SMGenerator is a winner and that's not a surprise. While we processing result our generator working on new value. This can significantly improve performance of your code on multicore devices.

Synchronous SMGenerator is also shows good results.

### Passing values into generator block: arguments vs. closure

SMGenerator offers two ways of passign value into the user block: via argument or just using variable from outer scope. The first variant is more robust (especially with asynchronous version) and more explaining. But more over it's a little bit more efficient (acording to performance test results, which are not presented here).

## Conclusion

SMGenerator suggests another way for creating generators in Objective-C. It has simple and neat syntax. And in the real world code it shouldn't impact your performance, moreover using asynchronous version of SMGenerator you can trully simple get very fast and efficient generator.

If you have any questions, sugestion or patches contact me at shkutkov@gmail.com.

## Licence

SMGenerator is released under an MIT license. For the full, legal license, see the LICENSE file. Use in any and every sort of project is encouraged, as long as the terms of the license are followed (and they're easy!).

