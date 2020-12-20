//
//  AMConverter.h
//  
//
//  Created by Gabriel Soria Souza on 17/09/20.
//

#import <Foundation/Foundation.h>
@import CoreFoundation;
@import AudioToolbox;

NS_ASSUME_NONNULL_BEGIN


@interface AMConverter : NSObject

- (instancetype)initWithSourceURLString:(NSString *)sourceURLString
                         destinationURL:(NSURL *)destinationURL
                             sampleRate:(Float64)sampleRate
                           outputFormat:(AudioFileTypeID)outputFormat;

@end

NS_ASSUME_NONNULL_END
