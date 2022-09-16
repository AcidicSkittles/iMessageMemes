//
//  CaptionGeneratorDelegate.h
//  iMessageMemeGenerator
//
//  Created by Derek Buchanan on 9/15/22.
//

#import <Foundation/Foundation.h>

#ifndef CaptionGeneratorDelegate_h
#define CaptionGeneratorDelegate_h

@protocol CaptionGeneratorDelegate <NSObject>
@required
- (void)finishedCaptionedMediaAtPath:(nullable NSURL*)captionedMediaPath withError:(nullable NSError*)error;
@end

#endif /* CaptionGeneratorDelegate_h */
