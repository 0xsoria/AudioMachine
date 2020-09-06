//
//  AudioKitMetadata.m
//  
//
//  Created by Gabriel Soria Souza on 23/06/20.
//

#import "AMMetadata.h"

@implementation AMMetadata

- (NSDictionary *)getFileMetadataAtURLString:(NSURL *)url {
    AudioFileID audioFile;
    OSStatus theErr = noErr;
    theErr = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFile);
    
    assert(theErr == noErr);
    
    UInt32 dictionarySize = 0;
    theErr = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, 0);
    
    assert(theErr == noErr);
    
    CFDictionaryRef dictionary;
    
    theErr = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, &dictionary);
    
    NSDictionary *returnData = [NSDictionary dictionaryWithDictionary:(__bridge NSDictionary * _Nonnull)(dictionary)];
    
    assert(theErr == noErr);
    
    CFRelease(dictionary);
    
    theErr = AudioFileClose(audioFile);
    
    assert(theErr == noErr);
    
    return returnData;
}

@end
