//
//  AudioKitMetadata.h
//  
//
//  Created by Gabriel Soria Souza on 23/06/20.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioKitMetadata : NSObject

- (NSDictionary *)getFileMetadataAtURLString:(NSString *)urlString;

@end

NS_ASSUME_NONNULL_END
