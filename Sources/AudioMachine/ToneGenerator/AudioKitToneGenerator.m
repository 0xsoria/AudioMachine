//
//  AudioKitToneGenerator.m
//  AudioKit
//
//  Created by Gabriel Soria Souza on 16/05/20.
//  Copyright © 2020 Gabriel Sória Souza. All rights reserved.
//

#import "AudioKitToneGenerator.h"

@interface AudioKitToneGenerator ()

@property OSStatus audioErr;
@property AudioFileID audioFile;
@property NSNumber *duration;
@property NSNumber *sampleRate;

@end

@implementation AudioKitToneGenerator

- (NSString *)defineFileNameWithWaveFormat:(WaveFormat)waveFormat {
    switch (waveFormat) {
        case SquareWave:
            return @"%0.3f-square.aif";
            break;
            
        case SineWave:
            return @"%0.3f-sine.aif";
            break;
            
        case SawtoothWave:
            return @"%0.3f-saw.aif";
            break;
    }
}

//writing samples to a file
- (void)toneGeneratorWithDuration:(NSNumber *)duration sampleRate:(NSNumber *)sampleRate frequency:(NSNumber *)frequency waveFormat:(WaveFormat)waveFormat andFileFormat:(AudioFileFormat)fileFormat {
    
    self.audioErr = noErr;
    
    double frequencyDoubleValue = [frequency doubleValue];
    NSString *defineFileName = [self defineFileNameWithWaveFormat:waveFormat];
    NSString *fileName = [NSString stringWithFormat:defineFileName, frequencyDoubleValue];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *urls = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *firstItem = [urls firstObject];
    NSURL *itemPathToBeSaved = [firstItem URLByAppendingPathComponent:fileName];
    
    //Preapare the format with universal traits of audio, such as how many samples it has, the format it's in, bit rate...
    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mSampleRate = [sampleRate floatValue];
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    //one channel per frame (Mono).
    asbd.mChannelsPerFrame = 1;
    asbd.mFramesPerPacket = 1;
    asbd.mBitsPerChannel = 16;
    asbd.mBytesPerFrame = 2;
    asbd.mBytesPerPacket = 2;
    
    //set up the file
    
    AudioFileTypeID fileFormatDefinition = [self audioTypeWithFormat:fileFormat];
    
    self.audioErr = AudioFileCreateWithURL((__bridge CFURLRef)itemPathToBeSaved, fileFormatDefinition, &asbd, kAudioFileFlags_EraseFile, &_audioFile);
    
    assert(self.audioErr == noErr);
    
    //start writing samples
    long maxSampleCount = [sampleRate longValue] * [duration longValue];
    long sampleCount = 0;
    
    UInt32 bytesToWrite = 2;
    double waveLenghtInSample = [sampleRate doubleValue] / [frequency doubleValue];
    
    while (sampleCount < maxSampleCount) {
        switch (waveFormat) {
            case SquareWave:
                [self writeSamplesForSquareWaveFormatWithWaveLenght:waveLenghtInSample sampleCount:&sampleCount bytesToWrite:&bytesToWrite];
                break;
                
            case SineWave:
                [self writeSamplesForSineWaveFormatWithWaveLenght:waveLenghtInSample sampleCount:&sampleCount bytesToWrite:&bytesToWrite];
                break;
                
            case SawtoothWave:
                [self writeSamplesForSAWWaveFormatWithWaveLenght:waveLenghtInSample sampleCount:&sampleCount bytesToWrite:&bytesToWrite];
                break;
        }
    }
    
    self.audioErr = AudioFileClose(self.audioFile);
    
    assert(self.audioErr == noErr);
    
    NSLog(@"wrote %ld samples", sampleCount);
}

- (void)writeSamplesForSineWaveFormatWithWaveLenght:(double)waveLenght sampleCount:(long *)sampleCount bytesToWrite:(UInt32 *)bytesToWrite {
    for (int i = 0; i < waveLenght; i++) {
        //saw wave
        SInt16 sample = CFSwapInt16HostToBig((SInt16)SHRT_MAX * sin(2 * M_PI * (i / waveLenght)));
        
        unsigned long long t1 = (unsigned long long)sampleCount * 2;
        self.audioErr = AudioFileWriteBytes(self.audioFile, false, t1, bytesToWrite, &sample);
        
        assert(self.audioErr == noErr);
        sampleCount++;
    }
}

- (void)writeSamplesForSquareWaveFormatWithWaveLenght:(double)waveLenght sampleCount:(long *)sampleCount bytesToWrite:(UInt32 *)bytesToWrite {
    for (int i = 0; i < waveLenght; i++) {
        //square wave
        SInt16 sample;
        if (i < waveLenght / 2) {
            sample = CFSwapInt16HostToBig(SHRT_MAX);
        } else {
            sample = CFSwapInt16HostToBig(SHRT_MIN);
        }
        unsigned long long t1 = (unsigned long long)sampleCount * 2;
        self.audioErr = AudioFileWriteBytes(self.audioFile, false, t1, bytesToWrite, &sample);
        
        assert(self.audioErr == noErr);
        
        sampleCount++;
    }
}

- (void)writeSamplesForSAWWaveFormatWithWaveLenght:(double)waveLenght sampleCount:(long *)sampleCount bytesToWrite:(UInt32 *)bytesToWrite {
    for (int i = 0; i < waveLenght; i++) {
        //saw wave
        SInt16 sample = CFSwapInt16HostToBig(((i / waveLenght) * SHRT_MAX * 2) - SHRT_MAX);
        
        unsigned long long t1 = (unsigned long long)sampleCount * 2;
        self.audioErr = AudioFileWriteBytes(self.audioFile, false, t1, bytesToWrite, &sample);
        
        assert(self.audioErr == noErr);
        sampleCount++;
    }
}

- (AudioFileTypeID)audioTypeWithFormat:(AudioFileFormat)audioType {
    switch (audioType) {
        case AIFFFormat:
            return kAudioFileAIFFType;
            break;
        case AIFCFormat:
            return kAudioFileAIFCType;
            break;
        case WAVEFormat:
            return kAudioFileWAVEType;
            break;
        case RF64Format:
            return kAudioFileRF64Type;
            break;
        case MP3Format:
            return kAudioFileMP3Type;
            break;
        case MP2Format:
            return kAudioFileMP2Type;
            break;
        case MP1Format:
            return kAudioFileMP1Type;
            break;
        case AC3Format:
            return kAudioFileAC3Type;
            break;
        case AACFormat:
            return kAudioFileAAC_ADTSType;
            break;
        case MPEG4Format:
            return kAudioFileMPEG4Type;
            break;
        case M4AFormat:
            return kAudioFileM4AType;
            break;
        case M4BFormat:
            return kAudioFileM4BType;
            break;
        case CAFFormat:
            return kAudioFileCAFType;
            break;
        case Type3GPFormat:
            return kAudioFile3GPType;
            break;
        case Type3GP2Format:
            return kAudioFile3GP2Type;
            break;
        case AMRFormat:
            return kAudioFileAMRType;
            break;
        case FLACFormat:
            return kAudioFileFLACType;
            break;
        case LATMinLOASTType:
            return kAudioFileLATMInLOASType;
            break;
    }
}

@end
