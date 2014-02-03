# SMGenerator: experimental fast and easy way to create generators in Objective-C

## Overview

As you might know Objecteve-C doesn't support [generators](http://en.wikipedia.org/wiki/Generator_(computer_science)) natively, but they may be useful to express some ideas. For example Python has such support and sometimes they are used [very intensively](http://www.dabeaz.com/generators/). The simplest generator that make any sense in Python looks like this:

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

Thus it's possible to get values simply sending *next* message to generator:

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

SMGenerator uses [GCD](http://en.wikipedia.org/wiki/Grand_Central_Dispatch) to run user block on its own queue. Thus this block works in another thread and synchronization with the orignal one (not only main thread, it maybe any thread that created your generator) are achived using semaphores. Actually user code works only when the orignal thread is blocked:

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
* It is possible to use return statement inside user block, but this stops generator (nil will be returned, if you send "next" message to generator)
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

What is the price of using generators and especially SMGenerator?

Let's do some tests and compare synchronous and asynchronous SMGenerator, MAGenerator, EXTCoroutine and the same task implemented without generator at all.

For each test we measure each implementation execution 10 times and than exclude 2 maximum and 2 minumum values and then calculate median. 
All code related all tests (iOS, OSX) you can find [in this project on Github](https://github.com/shkutkov/ObjectiveCGeneratorsPerformance). You can grab the project and run it by yourself. I've run iOS test on iOS Simulator and iPhone 5, OSX tests on my MacBookPro 13" (2,26Gh Intel Core 2 Duo).

#### Test #1: Generating numbers from 1 to 100000

|Implementation| iOS Simulator | iPhone 5 | MacBookPro |
|---------|---------:|---------:|---------:|
| Synchronous SMGenerator | 1.350800 | 3.800238 | 0.883701 |
| Asynchronous SMGenerator | 1.049956 | 3.843883 | 0.889207 |
| MAGenerator | 0.059778 | 0.214627 | 0.012960 |
| EXTCoroutine | 0.039936 | 0.116216 | 0.003566 |
| Without generator| 0.002214 | 0.010248 |0.001619|

As you can see SMGenerator both synchronous and asynchrous version are loosers in this synthetic test.

#### Test #2: Printing numbers from 1 to 100000 to the console

Let's take the same implementation and just print 1000 values to the console. 

|Generator Name| iOS Simulator | iPhone 5 | MacBookPro |
|---------|---------:|---------:|---------:|
| Synchronous SMGenerator | 0.705184 | 0.658221 | 0.293223 |
| Asynchronous SMGenerator | 0.695445 | 0.637643 | 0.275483 | 
| MAGenerator | 0.652017 | 0.580639 | 0.246619 |
| EXTCoroutine | 0.646062 | 0.581865 | 0.244638 |
| Without generator| 0.639307 | 0.562586 | 0.214950 |

As you can see in this example there is almostly no difference between SMGenerator and other implementation. 

Let's look at the last example with heave calculations. 

The code for calculating prime numbers will be rather inefficient, but it's not a big problem for our case - we just need a "heave" task in generator. (Please take a look at [PrimeNumbersGeneratorManager](https://github.com/shkutkov/ObjectiveCGeneratorsPerformance/blob/master/Classes/PerformanceTests/GeneratorManagers/PrimeNumbersGeneratorManager.m) if you are interesting in the code)

#### Test #3: Generating first 1000 prime numbers that are bigger than 100000 and printing them to the console

|Generator Name| iOS Simulator | iPhone 5 | MacBookPro |
|---------|---------:|---------:|---------:|
| Synchronous SMGenerator | 1.319347 | 4.643134 | 3.077379 |
| Asynchronous SMGenerator | 1.192727| 4.269168 | 2.797900 |
| MAGenerator | 1.972622 | 4.876356 | 3.539097 |
| EXTCoroutine | 1.973660 | 4.878249 | 3.540615 |
| Without generator| 1.097907 | 3.298502 | 2.108130 |

In this example we simulate the case when value generation takes some time and there is a processing of that value. Implementation without generators are not good in terms of code elegancy, but it's really fast. Also you can see, that asynchronous version of SMGenerator is the fastest implementation among other generator implementations. And this is not surprising, while we processing result our generator is working on a new value. This can improve performance of your code on multicore processors.

### Passing values into generator block: arguments vs. closure

SMGenerator offers two ways of passing value into the user block: via argument or just using variable from outer scope. The first variant is more robust (especially with asynchronous version) and more explaining. But moreover it's a little bit more efficient (acording to performance test results, which are not presented here).

## Conclusion

* Using generators can have slight impact on you app performance, so choose them wisely.
* SMGenerator suggests another way for creating generators in Objective-C. It has simple and neat syntax.
* In the real world code all generators have similar performance.
* Using asynchronous version of SMGenerator you can trully simple get very fast and efficient generator.

If you have any questions, sugestion or patches contact me at shkutkov@gmail.com.

## Licence

SMGenerator is released under an MIT license. For the full, legal license, see the LICENSE file. Use in any and every sort of project is encouraged, as long as the terms of the license are followed (and they're easy!).

