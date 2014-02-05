//
//  main.m
//  SMGenerator
//
//  Created by Mikhail Shkutkov on 06/02/14.
//  Copyright (c) 2014 Mikhail Shkutkov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SMGenerator.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        SMGenerator *generator = SM_GENERATOR(^(NSNumber *from, NSNumber *upto) {
            while ([from integerValue] <= [upto integerValue]) {
                SM_YIELD(from);
                from = @([from intValue] + 1);
            }
        }, @42, @52);
        
        for (NSNumber *num in generator) {
            NSLog(@"Number %@", num);
        }
        
    }
    
    return 0;
}

