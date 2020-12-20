//
//  MyClass.m
//  
//
//  Created by Gabriel Soria Souza on 17/09/20.
//

#import "AMConverter.h"

typedef struct AMAudioConverterSettings {
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;
    
    AudioFileID inputFile;
    AudioFileID outputFile;
    
    UInt64 inputFilePacketIndex;
    UInt64 inputFilePacketCount;
    UInt32 inputFilePacketMaxSize;
    AudioStreamPacketDescription *inputFilePacketDescriptions;
    
    void *sourceBuffer;
} AMAudioConverterSettings;

OSStatus AMAudioConverterCallback(AudioConverterRef inAudioConverter,
                                  UInt32 *ioDataPacketCount,
                                  AudioBufferList *ioData,
                                  AudioStreamPacketDescription **outDataPacketDescription,
                                  void *inUserData) {
    
    AMAudioConverterSettings *audioConverterSettings = (AMAudioConverterSettings *)inUserData;
    ioData->mBuffers[0].mData = NULL;
    ioData->mBuffers[0].mDataByteSize = 0;
    
    if (audioConverterSettings->inputFilePacketIndex + *ioDataPacketCount > audioConverterSettings->inputFilePacketCount)
        *ioDataPacketCount = (UInt32)audioConverterSettings->inputFilePacketCount - (UInt32)audioConverterSettings->inputFilePacketIndex;
    
    if (*ioDataPacketCount == 0)
        return noErr;
    
    if (audioConverterSettings->sourceBuffer != NULL) {
        free(audioConverterSettings->sourceBuffer);
        audioConverterSettings->sourceBuffer = NULL;
    }
    
    audioConverterSettings->sourceBuffer = (void *)calloc(1, *ioDataPacketCount * audioConverterSettings->inputFilePacketMaxSize);
    
    
    UInt32 outByteCount = 0;
    OSStatus result = AudioFileReadPacketData(audioConverterSettings->inputFile,
                                              true,
                                              &outByteCount,
                                              audioConverterSettings->inputFilePacketDescriptions,
                                              audioConverterSettings->inputFilePacketIndex,
                                              ioDataPacketCount,
                                              audioConverterSettings->sourceBuffer);
    if (result == kAudioFileEndOfFileError && *ioDataPacketCount)
        result = noErr;
    else if (result != noErr)
        return result;
    
    audioConverterSettings->inputFilePacketIndex += *ioDataPacketCount;
    ioData->mBuffers[0].mData = audioConverterSettings->sourceBuffer;
    ioData->mBuffers[0].mDataByteSize = outByteCount;
    
    if (outDataPacketDescription)
        *outDataPacketDescription = audioConverterSettings->inputFilePacketDescriptions;
    
    return result;
}

static void CheckResult(OSStatus result, const char *operation) {
    if (result == noErr) return;
    
    char errorString[20];
    //see if it appears to be a 4 char code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(result);
}

static void CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return;
    
    char errorString[20];
    //See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else sprintf(errorString, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    
    //add delegate
}


@implementation AMConverter

- (instancetype)initWithSourceURLString:(NSString *)sourceURLString
                         destinationURL:(NSURL *)destinationURL
                             sampleRate:(Float64)sampleRate
                           outputFormat:(AudioFileTypeID)outputFormat {

    
    //Create a AMAudioConverterSettings Struct and Opening a source audio file for conversion
    AMAudioConverterSettings audioConverterSettings = { 0 };
    NSString *urlPath = [NSURL URLWithString:sourceURLString].path;
    
    CFURLRef inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                          (CFStringRef)urlPath,
                                                          kCFURLPOSIXPathStyle,
                                                          false);
    
    CheckError (AudioFileOpenURL(inputFileURL,
                                 kAudioFileReadPermission,
                                 0,
                                 &audioConverterSettings.inputFile),
                "AudioFileOpenURL failed");
    
    CFRelease(inputFileURL);
    
    //GET ASBD from an input audio file
    
    UInt32 propSize = sizeof(audioConverterSettings.inputFormat);
    CheckError (AudioFileGetProperty(audioConverterSettings.inputFile,
                                     kAudioFilePropertyDataFormat,
                                     &propSize,
                                     &audioConverterSettings.inputFormat),
                "Could not get file's data format");
    
    //getting packet count and maximum packet size properties from input audio file
    //get the total number of packets in the file
    propSize = sizeof(audioConverterSettings.inputFilePacketCount);
    CheckError (AudioFileGetProperty(audioConverterSettings.inputFile,
                                     kAudioFilePropertyAudioDataPacketCount,
                                     &propSize,
                                     &audioConverterSettings.inputFilePacketCount),
                "could not get file's packet count");
    //get size of the largest possible packet
    propSize = sizeof(audioConverterSettings.inputFilePacketMaxSize);
    
    CheckError (AudioFileGetProperty(audioConverterSettings.inputFile,
                                     kAudioFilePropertyMaximumPacketSize,
                                     &propSize,
                                     &audioConverterSettings.inputFilePacketMaxSize),
                "could not get file's max packet size");
    //setup the output file
    audioConverterSettings.outputFormat.mSampleRate = 44100.0;
    audioConverterSettings.outputFormat.mFormatID = kAudioFormatLinearPCM;
    audioConverterSettings.outputFormat.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioConverterSettings.outputFormat.mBytesPerPacket = 4;
    audioConverterSettings.outputFormat.mFramesPerPacket = 1;
    audioConverterSettings.outputFormat.mBytesPerFrame = 4;
    audioConverterSettings.outputFormat.mChannelsPerFrame = 2;
    audioConverterSettings.outputFormat.mBitsPerChannel = 16;
    
    NSMutableString *destinationPath = [NSMutableString stringWithString:destinationURL.path];
    [destinationPath appendString:@"/output.aif"];
    
    CFURLRef outputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                           (CFStringRef)destinationPath,
                                                           kCFURLPOSIXPathStyle,
                                                           false);
    CheckError (AudioFileCreateWithURL(outputFileURL,
                                       outputFormat,
                                       &audioConverterSettings.outputFormat,
                                       kAudioFileFlags_EraseFile,
                                       &audioConverterSettings.outputFile),
                "AudioFileCreateWithURL failed");
    CFRelease(outputFileURL);
    
    fprintf(stdout, "Converting...\n");
    [self convertWith:&audioConverterSettings];
    
cleanup:
    AudioFileClose(audioConverterSettings.inputFile);
    AudioFileClose(audioConverterSettings.outputFile);
}

- (NSString  * _Nullable)outputFormatStringConverter:(AudioFileTypeID)format {
    switch (format) {
        case kAudioFileAIFCType:
            return @"AIF";
        case kAudioFileAIFFType:
            return @"AIF";
        default:
            return nil;
    }
}

- (void)convertWith:(AMAudioConverterSettings *)settings {
    //create the converter object
    AudioConverterRef audioConverter;
    CheckError(AudioConverterNew(&settings->inputFormat,
                                 &settings->outputFormat,
                                 &audioConverter), "AudioConverterNew failed");
    
    //determining the size of a packet buffers array and packets-per-buffer count for variable bit rate data
    
    UInt32 packetsPerBuffer = 0;
    UInt32 outputBufferSize = 32 * 1024; //32KB is a good starting point
    UInt32 sizePerPacket = settings->inputFormat.mBytesPerPacket;
    
    if (sizePerPacket == 0) {
        UInt32 size = sizeof(sizePerPacket);
        CheckError(AudioConverterGetProperty(audioConverter,
                                             kAudioConverterPropertyMaximumOutputPacketSize,
                                             &size,
                                             &sizePerPacket),
                   "Could not get kAudioConverterPropertyMaximumOutputPacketSize");
        
        if (sizePerPacket > outputBufferSize)
            outputBufferSize = sizePerPacket;
        
        packetsPerBuffer = outputBufferSize / sizePerPacket;
        settings->inputFilePacketDescriptions = (AudioStreamPacketDescription*) malloc(sizeof(AudioStreamPacketDescription) * packetsPerBuffer);
    } else {
        packetsPerBuffer = outputBufferSize / sizePerPacket;
    }
    
    UInt8 *outputBuffer = (UInt8 *)malloc(sizeof(UInt8) * outputBufferSize);
    UInt32 outputFilePacketPosition = 0;
    while(1) {
        //Preparing an AudioBufferList to receive converted data
        AudioBufferList convertedData;
        convertedData.mNumberBuffers = 1;
        convertedData.mBuffers[0].mNumberChannels = settings->inputFormat.mChannelsPerFrame;
        convertedData.mBuffers[0].mDataByteSize = outputBufferSize;
        convertedData.mBuffers[0].mData = outputBuffer;
        
        UInt32 ioOutputDataPackets = packetsPerBuffer;
        OSStatus error = AudioConverterFillComplexBuffer(audioConverter,
                                                         AMAudioConverterCallback,
                                                         settings,
                                                         &ioOutputDataPackets,
                                                         &convertedData,
                                                         (settings->inputFilePacketDescriptions ? settings->inputFilePacketDescriptions : nil));
        
        if (error || !ioOutputDataPackets) {
            break;
        }
        
        //Write the converted data to the output file
        CheckResult(AudioFileWritePackets(settings->outputFile,
                                          FALSE,
                                          ioOutputDataPackets,
                                          NULL,
                                          outputFilePacketPosition / settings->outputFormat.mBytesPerPacket,
                                          &ioOutputDataPackets,
                                          convertedData.mBuffers[0].mData),
                    "Could not write packets to file");
        outputFilePacketPosition += (ioOutputDataPackets * settings->outputFormat.mBytesPerPacket);
    }
    AudioConverterDispose(audioConverter);
}


@end
