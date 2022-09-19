//
//  VideoMemeGeneratorProtocol.h
//  iMessageMemeGenerator
//
//  Created by Derek Buchanan on 9/17/22.
//

#import "CaptionGeneratorDelegate.h"
@import UIKit;

#ifndef VideoMemeGeneratorProtocol_h
#define VideoMemeGeneratorProtocol_h

@protocol VideoMemeGeneratorProtocol <NSObject>
@required
/// Add meme captions to videos. A default recommended output size is applied if input is too small. Output is always an MP4.
/// @param text The meme text to be placed above the video.
/// @param videoPath File url path to the video on disk to be captioned.
- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath;

/// Add meme captions to videos. Output is always an MP4.
/// @param text The meme text to be placed above the video.
/// @param videoPath File url path to the video on disk to be captioned.
/// @param desiredMinWidth The minimum output width resolution.
- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath withMinOutputResolutionWidth:(CGFloat)desiredMinWidth;

@property (nonatomic, weak) id<CaptionGeneratorDelegate> delegate;

@end

#endif /* VideoMemeGeneratorProtocol_h */
