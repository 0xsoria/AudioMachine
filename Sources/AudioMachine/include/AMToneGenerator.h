//
//  AudioKitToneGenerator.h
//  AudioKit
//
//  Created by Gabriel Soria Souza on 16/05/20.
//  Copyright © 2020 Gabriel Sória Souza. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AudioFileFormat) {
    AIFFFormat,
    AIFCFormat,
    WAVEFormat,
    RF64Format,
    MP3Format,
    MP2Format,
    MP1Format,
    AC3Format,
    AACFormat,
    MPEG4Format,
    M4AFormat,
    M4BFormat,
    CAFFormat,
    Type3GPFormat,
    Type3GP2Format,
    AMRFormat,
    FLACFormat,
    LATMinLOASTType
};

typedef NS_ENUM(NSInteger, WaveFormat) {
    SquareWave,
    SawtoothWave,
    SineWave
};

@interface AMToneGenerator : NSObject

- (void)toneGeneratorWithDuration:(NSNumber *)duration sampleRate:(NSNumber *)sampleRate frequency:(NSNumber *)frequency waveFormat:(WaveFormat)waveFormat andFileFormat:(AudioFileFormat)fileFormat;

@end

NS_ASSUME_NONNULL_END
