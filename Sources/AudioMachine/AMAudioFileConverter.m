//
//  AMAudioFileConverter.m
//  
//
//  Created by Gabriel Soria Souza on 07/09/20.
//

#import "AMAudioFileConverter.h"
@import AVFoundation;


enum {
    kMyAudioConverterErr_CannotResumeFromInterruptionError = 'CANT'
};

typedef NS_ENUM(NSInteger, AudioConverterState) {
    AudioConverterStateInitial,
    AudioConverterStateRunning,
    AudioConverterStatePaused,
    AudioConverterStateDone
};

@interface AMAudioFileConverter ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, assign) AudioConverterState state;

@end

@implementation AMAudioFileConverter

- (instancetype)initWithSourceURL:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL sampleRate:(Float64)sampleRate outputFormat:(AudioFormatID)outputFormat {
    if ((self = [super init])) {
        _sourceURL = sourceURL;
        _destinationURL = destinationURL;
        _sampleRate = sampleRate;
        _outputFormat = outputFormat;
        _state = AudioConverterStateInitial;
        _queue = dispatch_queue_create("com.audiomachine.AMAudioFileConverter.queue",
                                           DISPATCH_QUEUE_CONCURRENT);
        _semaphore = dispatch_semaphore_create(0);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioSessionInterruptionNotification:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:[AVAudioSession sharedInstance]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:[AVAudioSession sharedInstance]];
}

- (void)startConverting {
    [self start];
}

- (void)main {
    [super main];
    
    assert(![NSThread isMainThread]);
    
    __weak __typeof__(self) weakSelf = self;
    
    dispatch_sync(self.queue, ^{
        weakSelf.state = AudioConverterStateRunning;
    });
    
    ExtAudioFileRef sourceFile = 0;
    
    if (![self checkError:ExtAudioFileOpenURL((__bridge CFURLRef _Nonnull)(self.sourceURL),
                                              &sourceFile) withErrorString:[NSString stringWithFormat:@"ExtAudioFileOpenURL failed for source file with URL %@", self.sourceURL]]) {
        return;
    }
    
    //Get the source data format;
    AudioStreamBasicDescription sourceFormat = {};
    UInt32 size = sizeof(sourceFormat);
    
    if (![self checkError:ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat) withErrorString:@"ExtAudioFileGetProperty couldn't get the source data format"]) {
        return;
    }
    
    //Setup the output file format.
    AudioStreamBasicDescription destinationFormat = {};
    destinationFormat.mSampleRate = (self.sampleRate == 0 ? sourceFormat.mSampleRate : self.sampleRate);
    
    if (self.outputFormat == kAudioFormatLinearPCM) {
        //if output format is PCM, create a 16-bit file format description.
        destinationFormat.mFormatID = self.outputFormat;
        destinationFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
        destinationFormat.mBitsPerChannel = 16;
        destinationFormat.mBytesPerPacket = destinationFormat.mBytesPerFrame = 2 * destinationFormat.mChannelsPerFrame;
        destinationFormat.mFramesPerPacket = 1;
        destinationFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger;
        
    } else {
        destinationFormat.mFormatID = self.outputFormat;
        destinationFormat.mChannelsPerFrame = (self.outputFormat == kAudioFormatiLBC ? 1 : sourceFormat.mChannelsPerFrame);
        
        size = sizeof(destinationFormat);
        
        if (![self checkError:AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destinationFormat) withErrorString:@"AudioFormatGetProperty couldn't fill out the destination data format"]) {
            return;
        }
    }
    
    printf("Source file format: \n");
    [AMAudioFileConverter printAudioStreamBasicDescription:sourceFormat];
    printf("Destination file format:\n");
    [AMAudioFileConverter printAudioStreamBasicDescription:destinationFormat];
    
    //Create destination audio file.
    ExtAudioFileRef destinationFile = 0;
    if (![self checkError:ExtAudioFileCreateWithURL((__bridge CFURLRef _Nonnull)(self.destinationURL), kAudioFileCAFType, &destinationFormat, NULL, kAudioFileFlags_EraseFile, &destinationFile) withErrorString:@"ExtAudioFileCreateWithURL failed!"]) {
        return;
    }
    
    AudioStreamBasicDescription clientFormat;
    if (self.outputFormat == kAudioFormatLinearPCM) {
        clientFormat = destinationFormat;
    } else {
        clientFormat.mFormatID = kAudioFormatLinearPCM;
        UInt32 sampleSize = sizeof(SInt32);
        clientFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        clientFormat.mBitsPerChannel = 8 * sampleSize;
        clientFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
        clientFormat.mFramesPerPacket = 1;
        clientFormat.mBytesPerPacket = clientFormat.mBytesPerFrame = sourceFormat.mChannelsPerFrame * sampleSize;
        clientFormat.mSampleRate = sourceFormat.mSampleRate;
    }
    
    printf("Client file format:\n");
    [AMAudioFileConverter printAudioStreamBasicDescription:clientFormat];
    
    size = sizeof(clientFormat);
    
    if (![self checkError:ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat)
          withErrorString:@"Couldn't set the client format on the source file!"]) {
        return;
    }
    
    size = sizeof(clientFormat);
    if (![self checkError:ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat) withErrorString:@"Couldn't set the client format on the destination file!"]) {
        return;
    }
    
    //Get the audio converter;
    AudioConverterRef converter = 0;
    
    size = sizeof(converter);
    if (![self checkError:ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &converter) withErrorString:@"Failed to get the Audio Converter from the destination file."]) {
        return;
    }
    
    BOOL canResumeFromInterruption = YES;
    UInt32 canResume = 0;
    size = sizeof(canResume);
    OSStatus error = AudioConverterGetProperty(converter, kAudioConverterPropertyCanResumeFromInterruption, &size, &canResume);
    
    if (error == noErr) {
        /*
         we recieved a valid return value from the GetProperty call
         if the property's value is 1, then the codec CAN resume work following an interruption
         if the property's value is 0, then interruptions destroy the codec's state and we're done
         */
        if (canResume == 0) {
            canResumeFromInterruption = NO;
        }
        printf("Audio Converter %s continue after interruption\n", (!canResumeFromInterruption ? "CANNOT" : "CAN"));
    } else {
        /*
         if the property is unimplemented (kAudioConverterErr_PropertyNotSupported, or paramErr returned in the case of PCM),
         then the codec being used is not a hardware codec so we're not concerned about codec state
         we are always going to be able to resume conversion after an interruption
         */
        
        if (error == kAudioConverterErr_PropertyNotSupported) {
            printf("kAudioConverterPropertyCanResumeFromInterruption property not supported - see comments in source for more info.\n");
            
        } else {
            printf("AudioConverterGetProperty kAudioConverterPropertyCanResumeFromInterruption result %d, paramErr is OK if PCM\n", (int)error);
        }
        error = noErr;
    }
    
    //Setup buffers
    UInt32 bufferByteSize = 32768;
    char sourceBuffer[bufferByteSize];
    
    /*
     keep track of the source file offset so we know where to reset the source for
     reading if interrupted and input was not consumed by the audio converter
     */
    SInt64 sourceFrameOffset = 0;
    
    //Do the read and write - the conversion is done on and by the write call;
    
    printf("Convertig...\n");
    
    while (YES) {
        //set up output buffer list.
        AudioBufferList fillBufferList = {};
        fillBufferList.mNumberBuffers = 1;
        fillBufferList.mBuffers[0].mNumberChannels = clientFormat.mChannelsPerFrame;
        fillBufferList.mBuffers[0].mDataByteSize = bufferByteSize;
        fillBufferList.mBuffers[0].mData = sourceBuffer;
        
        UInt32 numberOfFrames = 0;
        if (clientFormat.mBytesPerFrame > 0) {
            numberOfFrames = bufferByteSize / clientFormat.mBytesPerFrame;
        }
        
        if (![self checkError:ExtAudioFileRead(sourceFile, &numberOfFrames, &fillBufferList) withErrorString:@"ExtAudioFileRead failed!"]) {
            return;
        }
        
        if (!numberOfFrames) {
            error = noErr;
            break;
        }
        
        sourceFrameOffset += numberOfFrames;
        
        BOOL wasInterrupted = [self checkIfPausedDueToInterruption];
        
        if ((error != noErr || wasInterrupted) && (!canResumeFromInterruption)) {
            error = kMyAudioConverterErr_CannotResumeFromInterruptionError;
            break;
        }
        
        error = ExtAudioFileWrite(destinationFile, numberOfFrames, &fillBufferList);
        if (error != noErr) {
            if (error == kExtAudioFileError_CodecUnavailableInputConsumed) {
                printf("ExtAudioFileWrite kExtAudioFileError_CodecUnavailableInputConsumed error %d\n", (int)error);
                
            } else if (error == kExtAudioFileError_CodecUnavailableInputNotConsumed) {
                printf("ExtAudioFileWrite kExtAudioFileError_CodecUnavailableInputNotConsumed error %d\n", (int)error);
                
                sourceFrameOffset -= numberOfFrames;
                if (![self checkError:ExtAudioFileSeek(sourceFile, sourceFrameOffset) withErrorString: @"ExtAudioFileSeek failed!"]) {
                    return;
                }
            } else {
                [self checkError:error withErrorString:@"ExtAudioFileWrite failed!"];
            }
        }
    }
    
    if (destinationFile) { ExtAudioFileDispose(destinationFile); }
    if (sourceFile) { ExtAudioFileDispose(sourceFile); }
    if (converter) { AudioConverterDispose(converter); }
    
    dispatch_sync(self.queue, ^{
        weakSelf.state = AudioConverterStateDone;
    });
    
    if (error == noErr) {
        if ([self.delegate respondsToSelector:@selector(audioFileConvertOperation:didCompleteWithURL:)]) {
            [self.delegate audioFileConvertOperation:self didCompleteWithURL:self.destinationURL];
        }
    }
}


- (BOOL)checkError:(OSStatus)error withErrorString:(NSString *)string {
    if (error == noErr) {
        return YES;
    }
    
    if ([self.delegate respondsToSelector:@selector(audioFileConvertOperation:didEncounterError:)]) {
        NSError *err = [NSError errorWithDomain:@"AudioFileConvertOperationErrorDomain"
                                           code:error
                                       userInfo:@{NSLocalizedDescriptionKey: string}];
        [self.delegate audioFileConvertOperation:self didEncounterError:err];
    }
}

- (BOOL)checkIfPausedDueToInterruption {
    __block BOOL wasInterrupted = NO;
    
    __weak __typeof__(self) weakSelf = self;
    dispatch_sync(self.queue, ^ {
        assert(weakSelf.state != AudioConverterStateDone);
        
        while(weakSelf.state == AudioConverterStatePaused) {
            dispatch_semaphore_wait(weakSelf.semaphore, DISPATCH_TIME_FOREVER);
            wasInterrupted = YES;
        }
    });
    
    assert(self.state == AudioConverterStateRunning);
    
    return wasInterrupted;
}


- (void)handleAudioSessionInterruptionNotification:(NSNotification *)notification {
    AVAudioSessionInterruptionType interruptionType =  [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    
    printf("Session interrupted > --- %s ---\n", interruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
    
    __weak __typeof__(self) weakSelf = self;
    
    if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
        dispatch_sync(self.queue, ^{
            if (weakSelf.state == AudioConverterStateRunning) {
                weakSelf.state = AudioConverterStatePaused;
            }
        });
    } else {
        NSError *error = nil;
        
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        
        if (error != nil) {
            NSLog(@"AVAudioSession setActive failed with error %@", error.localizedDescription);
        }
        
        if (self.state == AudioConverterStatePaused) {
            dispatch_semaphore_signal(self.semaphore);
        }
        
        dispatch_sync(self.queue, ^{
            weakSelf.state = AudioConverterStateRunning;
        });
    }
}

+ (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy(&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}

@end
