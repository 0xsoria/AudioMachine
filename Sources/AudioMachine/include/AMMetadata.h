//
//  AudioKitMetadata.h
//  
//
//  Created by Gabriel Soria Souza on 23/06/20.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface AMMetadata : NSObject

- (NSDictionary *)getFileMetadataAtURLString:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
