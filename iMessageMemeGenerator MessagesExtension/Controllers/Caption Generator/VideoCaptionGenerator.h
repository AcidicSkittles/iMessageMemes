//
//  VideoCaptionGenerator.h
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

#import <Foundation/Foundation.h>
#import "CaptionGeneratorDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface VideoCaptionGenerator : NSObject
@property (nonatomic, weak) id<CaptionGeneratorDelegate> delegate;

/// Add meme captions to videos. The default output resolution width is 640.
/// @param text The meme text to be placed above the video.
/// @param videoPath File url path to the video on disk to be captioned.
- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath;

/// Add meme captions to videos.
/// @param text The meme text to be placed above the video.
/// @param videoPath File url path to the video on disk to be captioned.
/// @param desiredMinWidth The minimum output width resolution.
- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath withMinOutputResolution:(int)desiredMinWidth;

@end

NS_ASSUME_NONNULL_END
