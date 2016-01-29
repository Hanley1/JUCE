/*
 ==============================================================================
 
 This file is part of the JUCE library.
 Copyright (c) 2013 - Raw Material Software Ltd.
 
 Permission is granted to use this software under the terms of either:
 a) the GPL v2 (or any later version)
 b) the Affero GPL v3
 
 Details of these licenses can be found at: www.gnu.org/licenses
 
 JUCE is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 
 ------------------------------------------------------------------------------
 
 To release a closed-source product which uses JUCE, commercial licenses are
 available: visit www.juce.com for more information.
 
 ==============================================================================
 */

#include "juce_ios_Audio.h"

#if JUCE_IOS
#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AudioToolbox.h>
#endif

} // juce namespace

// AB
#import "Audiobus.h"

@interface Wrapper : NSObject
{
    juce::iOSAudioIODevice* owner;
    
    // AB
    ABSenderPort *audiobusOutput;
}

// AB
@property (readonly) ABSenderPort* audiobusOutput;
@property (strong, nonatomic) ABAudiobusController* audiobusController;
@property bool isRegistered;
@property bool isActivated;

- (void) stop;
- (void) start;

- (void)registerForRouteChangeNotification;

-(void)applicationDidEnterBackground:(NSNotification *)notification;
-(void)applicationWillEnterForeground:(NSNotification *)notification;

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context;

- (void)routeChange:(NSNotification*)notification;
- (void)activateAudiobus:(AudioUnit)outputUnit;

@end

//static void * kAudiobusRunningOrConnectedChanged = &kAudiobusRunningOrConnectedChanged;
static void * kMemberOfActiveAudiobusSessionChanged = &kMemberOfActiveAudiobusSessionChanged;
static void * kAudiobusConnectedChanged = &kAudiobusConnectedChanged;
static Wrapper *wrapper = nil;

@implementation Wrapper

// AB
@synthesize audiobusOutput;
@synthesize audiobusController;
@synthesize isRegistered;
@synthesize isActivated;

+ (id)sharedInstance
{
    if (wrapper == nil)
        wrapper = [[Wrapper alloc] init];
    
    return wrapper;
}

- (void)assignOwner: (juce::iOSAudioIODevice*) owner_
{
    owner = owner_;
}

- (void)dealloc {
    
    // AB
    [audiobusController removeSenderPort:audiobusOutput];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [audiobusController removeObserver:self forKeyPath:@"connected"];
    [audiobusController removeObserver:self forKeyPath:@"memberOfActiveAudiobusSession"];
    
    [super dealloc];
}

- (void) stop
{
    owner->stopAudioUnit();
}

- (void) start
{
    owner->startAudioUnit();
}

- (void) registerForRouteChangeNotification {
    
    if (!isRegistered)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(routeChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        isRegistered = true;
    }
}

- (void)routeChange:(NSNotification*)notification {
    
    DBG("route change");
    
    // It doesn't appear Juce needs to do anything with routing changes, so I haven't bothered with this yet:
    if (owner != 0)
        owner->routingChanged (notification);
}

-(void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self updateAudioEngineState];
    // uncomment if you want to stop the audio engine when going into the background and not connected to IAA or AudioBus. However, you'll need to stay on if you want to stay open for midi sequencing apps like Auxy, etc.
    /*
     if ( !audiobusController.connected && !audiobusController.memberOfActiveAudiobusSession )
     {
     // Fade out and stop the audio engine, suspending the app, if we're not connected, and we're not part of an active Audiobus session
     [ABAudioUnitFader fadeOutAudioUnit:owner->getAudioUnit() completionBlock:^{ [self stop]; }];
     //[self stop];
     }
     */
}

-(void)applicationWillEnterForeground:(NSNotification *)notification
{
    bool running = false;
    UInt32 size = sizeof(running);
    AudioUnitGetProperty(owner->getAudioUnit(), kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &running, &size);
    
    if (!running || [ABAudioUnitFader transitionsRunning] )
    {
        // fade in is causing problems when launchign app from IAA host. So we'll just abruptly start it
        //[ABAudioUnitFader fadeInAudioUnit:owner->getAudioUnit() beginBlock:^{ [self start]; } completionBlock:nil];
        [self start];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context {
    
    if ( context == kAudiobusConnectedChanged || context == kMemberOfActiveAudiobusSessionChanged )
    {
        /*
         bool memberChanged = context == kAudiobusConnectedChanged;
         bool connectChanged = context == kMemberOfActiveAudiobusSessionChanged;
         bool appInBG = [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
         bool kConnectChanged;
         
         if (kAudiobusConnectedChanged)
         kConnectChanged = true;
         else
         kConnectChanged = false;
         */
        
        if ( [UIApplication sharedApplication].applicationState == UIApplicationStateBackground
            && !audiobusController.connected
            && !audiobusController.memberOfActiveAudiobusSession )
        {
            // Audiobus session is finished. Time to sleep.
            [self stop];
        }
        
        if (kAudiobusConnectedChanged && audiobusController.connected )
        {
            // Make sure we're running, if we're connected
            [self start];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (void)activateAudiobus:(AudioUnit)outputUnit;
{
    // AB
    if (!isActivated)
    {
        audiobusController = [[ABAudiobusController alloc] initWithApiKey:@"MCoqKlN5bnRvcmlhbCoqKlN5bnRvcmlhbC0xLjAuYXVkaW9idXM6Ly8=:r4S2Z/ReJDNxoqja2RCGYyANvN8c9NtJHNE3mvO50sQ84oSw/gPsKQqMfkh34HE4CxEqHNmnqNzyVV4BXL3kpD5NNg3tqKrpcafAuJrK4zpFjjOIuu5IK4ZUXhCtVagU"]; //use your API key here
        
        audiobusController.connectionPanelPosition = ABConnectionPanelPositionRight; //choose where you want the Audiobus navigation widget to show up
        
        
        
        // port information needs to match the information entered into the .plist (see audiobus integration guide)
        audiobusOutput = [[ABSenderPort alloc] initWithName:@"Audible Genius: Syntorial"
                                                      title:NSLocalizedString(@"Audible Genius: Syntorial", @"")
                                  audioComponentDescription:(AudioComponentDescription)
                          {
                              .componentType = kAudioUnitType_RemoteInstrument,
                              .componentSubType = 'iasp', // Note single quotes
                              .componentManufacturer = 'agsy'
                          } //
                                                  audioUnit:outputUnit];
        
        [audiobusController addSenderPort:audiobusOutput];
        
        //would create filter or input ports here if I needed them
        
        // Watch the audiobusAppRunning and connected properties
        [audiobusController addObserver:self
                             forKeyPath:@"connected"
                                options:0
                                context:kAudiobusConnectedChanged];
        
        [audiobusController addObserver:self
                             forKeyPath:@"memberOfActiveAudiobusSession"
                                options:0
                                context:kMemberOfActiveAudiobusSessionChanged];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        isActivated = true;
    }
}

-(bool) areMIDISourcesOpen
{
    if (MIDIGetNumberOfSources() > 0)
        return true;
    else
        return false;
}

-(void) updateAudioEngineState
{
    if (![self areMIDISourcesOpen]
        && !audiobusController.connected
        && !audiobusController.memberOfActiveAudiobusSession
        && [UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
    {
        [ABAudioUnitFader fadeOutAudioUnit:owner->getAudioUnit() completionBlock:^{ [self stop]; }];
    }
    else
    {
        [self start];
    }
}

-(bool) isHostConnectedViaAudiobus
{
    return audiobusController.audiobusConnected;
}

@end



namespace juce {
    
    AudioUnit iOSAudioIODevice::audioUnit = 0;
    
    iOSAudioIODevice::iOSAudioIODevice (const String& deviceName)
    : AudioIODevice (deviceName, "Audio"),
    actualBufferSize (0),
    isRunning (false),
    callback (nullptr),
    floatData (1, 2)
    {
        // NEW
        if (audioUnit != 0)
            AudioOutputUnitStop(audioUnit);
        
        [[Wrapper sharedInstance] assignOwner:this];
        
        getSessionHolder().activeDevices.add (this);
        
        numInputChannels = 2;
        numOutputChannels = 2;
        preferredBufferSize = 0;
        
        updateDeviceInfo();
    }
    
    iOSAudioIODevice::~iOSAudioIODevice()
    {
        setAudioUnitCallback(false);
        getSessionHolder().activeDevices.removeFirstMatchingValue (this);
        close();
    }
    
    StringArray iOSAudioIODevice::getOutputChannelNames()
    {
        StringArray s;
        s.add ("Left");
        s.add ("Right");
        return s;
    }
    
    StringArray iOSAudioIODevice::getInputChannelNames()
    {
        StringArray s;
        if (audioInputIsAvailable)
        {
            s.add ("Left");
            s.add ("Right");
        }
        return s;
    }
    
    Array<double> iOSAudioIODevice::getAvailableSampleRates()
    {
        // can't find a good way to actually ask the device for which of these it supports..
        static const double rates[] = { 8000.0, 16000.0, 22050.0, 32000.0, 44100.0, 48000.0 };
        return Array<double> (rates, numElementsInArray (rates));
    }
    
    Array<int> iOSAudioIODevice::getAvailableBufferSizes()
    {
        Array<int> r;
        
        for (int i = 6; i < 12; ++i)
            r.add (1 << i);
        
        return r;
    }
    
    int iOSAudioIODevice::getDefaultBufferSize()
    {
        return 1024;
    }
    
    String iOSAudioIODevice::open (const BigInteger& inputChannelsWanted,
                                   const BigInteger& outputChannelsWanted,
                                   double targetSampleRate, int bufferSize)
    {
        close();
        
        lastError.clear();
        preferredBufferSize = (bufferSize <= 0) ? getDefaultBufferSize() : bufferSize;
        
        //  xxx set up channel mapping
        
        activeOutputChans = outputChannelsWanted;
        activeOutputChans.setRange (2, activeOutputChans.getHighestBit(), false);
        numOutputChannels = activeOutputChans.countNumberOfSetBits();
        monoOutputChannelNumber = activeOutputChans.findNextSetBit (0);
        
        activeInputChans = inputChannelsWanted;
        activeInputChans.setRange (2, activeInputChans.getHighestBit(), false);
        numInputChannels = activeInputChans.countNumberOfSetBits();
        monoInputChannelNumber = activeInputChans.findNextSetBit (0);
        
        // OLD
        // AudioSessionSetActive (true);
        
        if (numInputChannels > 0 && audioInputIsAvailable)
        {
            // NEW
            [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord
                                             withOptions: AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker |AVAudioSessionCategoryOptionAllowBluetooth
                                                   error:  &err];
            
            // OLD
            //setSessionUInt32Property (kAudioSessionProperty_AudioCategory, kAudioSessionCategory_PlayAndRecord);
            //setSessionUInt32Property (kAudioSessionProperty_OverrideCategoryEnableBluetoothInput, 1);
        }
        else
        {
            // NEW
            [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback
                                             withOptions: AVAudioSessionCategoryOptionMixWithOthers
                                                   error:  &err];
            // OLD
            //setSessionUInt32Property (kAudioSessionProperty_AudioCategory, kAudioSessionCategory_MediaPlayback);
        }
        
        
        // NEW
        [[AVAudioSession sharedInstance] setActive: YES error:  &err];
        
        if (audioUnit != 0)
            AudioOutputUnitStart(audioUnit);
        
        [[Wrapper sharedInstance] registerForRouteChangeNotification];
        [[AVAudioSession sharedInstance] setPreferredSampleRate:targetSampleRate error:&err];
        
        // OLD
        //AudioSessionAddPropertyListener (kAudioSessionProperty_AudioRouteChange, routingChangedStatic, this);
        //fixAudioRouteIfSetToReceiver();
        //setSessionFloat64Property (kAudioSessionProperty_PreferredHardwareSampleRate, targetSampleRate);
        
        updateDeviceInfo();
        
        // NEW
        [[AVAudioSession sharedInstance] setPreferredIOBufferDuration: preferredBufferSize/sampleRate error: &err];
        
        // OLD
        //setSessionFloat32Property (kAudioSessionProperty_PreferredHardwareIOBufferDuration, preferredBufferSize / sampleRate);
        
        updateCurrentBufferSize();
        prepareFloatBuffers (actualBufferSize);
        
        isRunning = true;
        routingChanged (nullptr);  // creates and starts the AU
        
        lastError = audioUnit != 0 ? "" : "Couldn't open the device";
        return lastError;
    }
    
    void iOSAudioIODevice::close()
    {
        if (isRunning)
        {
            isRunning = false;
            
            // NEW
            [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback
                                             withOptions: AVAudioSessionCategoryOptionMixWithOthers
                                                   error:  &err];
            // OLD
            /*
             setSessionUInt32Property (kAudioSessionProperty_AudioCategory, kAudioSessionCategory_MediaPlayback);
             AudioSessionRemovePropertyListenerWithUserData (kAudioSessionProperty_AudioRouteChange, routingChangedStatic, this);
             AudioSessionSetActive (false);
             
             if (audioUnit != 0)
             {
             AudioComponentInstanceDispose (audioUnit);
             audioUnit = 0;
             }
             */
        }
        
        // NEW
        if (audioUnit != 0)
            AudioOutputUnitStop(audioUnit);
        
        [[AVAudioSession sharedInstance] setActive: NO error:  &err];
        
    }
    
    bool iOSAudioIODevice::isOpen()                       { return isRunning; }
    
    int iOSAudioIODevice::getCurrentBufferSizeSamples()   { return actualBufferSize; }
    double iOSAudioIODevice::getCurrentSampleRate()       { return sampleRate; }
    int iOSAudioIODevice::getCurrentBitDepth()            { return 16; }
    
    BigInteger iOSAudioIODevice::getActiveOutputChannels() const    { return activeOutputChans; }
    BigInteger iOSAudioIODevice::getActiveInputChannels() const     { return activeInputChans; }
    
    int iOSAudioIODevice::getOutputLatencyInSamples()
    {
        // NEW
        double latency = [AVAudioSession sharedInstance].outputLatency;
        return roundToInt (latency * getCurrentSampleRate());
        
        // OLD
        //return getLatency (kAudioSessionProperty_CurrentHardwareOutputLatency);
    }
    
    int iOSAudioIODevice::getInputLatencyInSamples()
    {
        // NEW
        double latency = [AVAudioSession sharedInstance].inputLatency;
        return roundToInt (latency * getCurrentSampleRate());
        
        // OLD
        //return getLatency (kAudioSessionProperty_CurrentHardwareInputLatency);
    }
    
    // OLD
    /*
     int iOSAudioIODevice::getLatency (AudioSessionPropertyID propID)
     {
     Float32 latency = 0;
     getSessionProperty (propID, latency);
     return roundToInt (latency * getCurrentSampleRate());
     }
     */
    
    void iOSAudioIODevice::start (AudioIODeviceCallback* newCallback)
    {
        if (isRunning && callback != newCallback)
        {
            if (newCallback != nullptr)
                newCallback->audioDeviceAboutToStart (this);
            
            const ScopedLock sl (callbackLock);
            callback = newCallback;
        }
    }
    
    void iOSAudioIODevice::stop()
    {
        if (isRunning)
        {
            AudioIODeviceCallback* lastCallback;
            
            {
                const ScopedLock sl (callbackLock);
                lastCallback = callback;
                callback = nullptr;
            }
            
            if (lastCallback != nullptr)
                lastCallback->audioDeviceStopped();
        }
    }
    
    bool iOSAudioIODevice::isPlaying()            { return isRunning && callback != nullptr; }
    String iOSAudioIODevice::getLastError()       { return lastError; }
    
    bool iOSAudioIODevice::setAudioPreprocessingEnabled (bool enable)
    {
        // NEW
        return [[AVAudioSession sharedInstance] setMode: enable ? AVAudioSessionModeDefault : AVAudioSessionModeMeasurement
                                                  error:  &err];
        
        // OLD
        //return setSessionUInt32Property (kAudioSessionProperty_Mode, enable ? kAudioSessionMode_Default : kAudioSessionMode_Measurement);
    }
    
    // NEW
    void iOSAudioIODevice::routingChanged (const NSNotification* notification)
    {
        if (! isRunning)
            return;
        
        if (notification != nullptr)
        {
            //        CFDictionaryRef routeChangeDictionary = (CFDictionaryRef) propertyValue;
            //        CFNumberRef routeChangeReasonRef = (CFNumberRef) CFDictionaryGetValue (routeChangeDictionary,
            //                                                                                CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
            //
            //        SInt32 routeChangeReason;
            //        CFNumberGetValue (routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
            //
            //        if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable)
            //        {
            //            const ScopedLock sl (callbackLock);
            //
            //            if (callback != nullptr)
            //                callback->audioDeviceError ("Old device unavailable");
            //        }
            
            //again, not doing anything here, but if you wanted to:
            
            NSDictionary *routeChangeDict = notification.userInfo;
            
            NSInteger routeChangeReason = [[routeChangeDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
            
            switch (routeChangeReason) {
                case AVAudioSessionRouteChangeReasonUnknown:
                    NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonUnknown");
                    break;
                    
                case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
                    // a headset was added or removed
                    NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonNewDeviceAvailable");
                    break;
                    
                case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
                    // a headset was added or removed
                    NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonOldDeviceUnavailable");
                    break;
                    
                case AVAudioSessionRouteChangeReasonCategoryChange:
                    // called at start - also when other audio wants to play
                    NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonCategoryChange");//AVAudioSessionRouteChangeReasonCategoryChange
                    break;
                    
                case AVAudioSessionRouteChangeReasonOverride:
                    NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonOverride");
                    break;
                    
                case AVAudioSessionRouteChangeReasonWakeFromSleep:
                    NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonWakeFromSleep");
                    break;
                    
                case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
                    NSLog(@"routeChangeReason : AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory");
                    break;
                    
                default:
                    break;
            }
            
            if (routeChangeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
            {
                const ScopedLock sl (callbackLock);
                
                if (callback != nullptr)
                    callback->audioDeviceError ("Old device unavailable");
            }
        }
        
        updateDeviceInfo();
        
        if (audioUnit == 0)
            createAudioUnit();
        else
            setAudioUnitCallback(true);
        
        // OLD
        //AudioSessionSetActive (true);
        
        // NEW
        [[AVAudioSession sharedInstance] setActive: YES error:&err];
        
        if (audioUnit != 0)
        {
            AudioOutputUnitStart(audioUnit);
            
            UInt32 formatSize = sizeof (format);
            AudioUnitGetProperty (audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &format, &formatSize);
            
            updateCurrentBufferSize();
            AudioOutputUnitStart (audioUnit);
        }
    }
    
    void iOSAudioIODevice::closeAudioUnit()
    {
        stopAudioUnit();
        
        if (audioUnit != 0)
        {
            AudioComponentInstanceDispose (audioUnit);
            audioUnit = 0;
        }
        
        [[Wrapper sharedInstance] release];
    }
    
    void iOSAudioIODevice::stopAudioUnit()
    {
        if (audioUnit != 0)
            AudioOutputUnitStop(audioUnit);
        
        [[AVAudioSession sharedInstance] setActive: NO error:  &err];
    }
    
    void iOSAudioIODevice::startAudioUnit()
    {
        if (audioUnit != 0)
            AudioOutputUnitStart(audioUnit);
        
        [[AVAudioSession sharedInstance] setActive: YES error:  &err];
    }
    
    
    void iOSAudioIODevice::toggleHostPlayback()
    {
        if (audioUnit != 0)
        {
            UInt32 controlEvent = kAudioUnitRemoteControlEvent_TogglePlayPause;
            UInt32 dataSize = sizeof(controlEvent);
            
            AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_RemoteControlToHost, kAudioUnitScope_Global, 0, &controlEvent, dataSize);
        }
    }
    
    void iOSAudioIODevice::toggleHostRecord()
    {
        if (audioUnit != 0)
        {
            UInt32 controlEvent = kAudioUnitRemoteControlEvent_ToggleRecord;
            UInt32 dataSize = sizeof(controlEvent);
            
            AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_RemoteControlToHost, kAudioUnitScope_Global, 0, &controlEvent, dataSize);
        }
    }
    
    void iOSAudioIODevice::toggleHostRewind()
    {
        if (audioUnit != 0)
        {
            UInt32 controlEvent = kAudioUnitRemoteControlEvent_Rewind;
            UInt32 dataSize = sizeof(controlEvent);
            
            AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_RemoteControlToHost, kAudioUnitScope_Global, 0, &controlEvent, dataSize);
        }
    }
    
    void* iOSAudioIODevice::getHostIcon()
    {
        if (audioUnit != 0)
            return AudioOutputUnitGetHostIcon(audioUnit, 114);
        
        return nullptr;
    }
    
    void iOSAudioIODevice::goToHost()
    {
        if (audioUnit != 0)
        {
            CFURLRef instrumentUrl;
            UInt32 dataSize = sizeof(instrumentUrl);
            OSStatus result = AudioUnitGetProperty(audioUnit, kAudioUnitProperty_PeerURL, kAudioUnitScope_Global, 0, &instrumentUrl, &dataSize);
            
            if (result == noErr)
                [[UIApplication sharedApplication] openURL:(NSURL*)instrumentUrl];
        }
    }
    
    void iOSAudioIODevice::getHostTransportInfo(bool* isPlaying, bool* isRecording, String* playTimeString)
    {
        float playTime = 0.0;
        
        if (isHostConnectedViaIAA() && [UIApplication sharedApplication].applicationState !=  UIApplicationStateBackground)
        {
            HostCallbackInfo hostCallbackInfo;
            UInt32 dataSize = sizeof(HostCallbackInfo);
            OSStatus result = AudioUnitGetProperty(audioUnit, kAudioUnitProperty_HostCallbacks, kAudioUnitScope_Global, 0, &hostCallbackInfo, &dataSize);
            
            if (result == noErr)
            {
                Boolean isPlayingObjC  = false;
                Boolean isRecordingObjC = false;
                Float64 outCurrentSampleInTimeLine = 0;
                void* hostUserData = hostCallbackInfo.hostUserData;
                
                OSStatus result =  hostCallbackInfo.transportStateProc2(hostUserData,
                                                                        &isPlayingObjC,
                                                                        &isRecordingObjC, NULL,
                                                                        &outCurrentSampleInTimeLine,
                                                                        NULL, NULL, NULL);
                
                
                
                if (result == noErr)
                {
                    *isPlaying = isPlayingObjC;
                    *isRecording = isRecordingObjC;
                    playTime = outCurrentSampleInTimeLine;
                }
                else
                    NSLog(@"Error occured fetching callBackInfo->transportStateProc2 : %d", (int)result);
            }
            
        }
        
        if (playTime < 0.0)
            playTime = 0.0;
        
        int totalMilliseconds = playTime / [[AVAudioSession sharedInstance] sampleRate] * 1000.0;
        int minutes = totalMilliseconds / 60000;
        int secondsLeft = totalMilliseconds % 60000;
        int seconds = secondsLeft / 1000;
        int milliseconds = secondsLeft % 1000;
        
        String minutesString = String(minutes);
        String secondsString = String(seconds);
        String millisecondsString = String(milliseconds);;
        
        if (minutes < 10)
            minutesString = "0" + minutesString;
        
        if (seconds < 10)
            secondsString = "0" + secondsString;
        
        if (milliseconds < 10)
            millisecondsString = "00" + millisecondsString;
        else if (milliseconds < 100)
            millisecondsString = "0" + millisecondsString;
        
        *playTimeString = minutesString + ":" + secondsString + ":" + millisecondsString;
    }
    
    float iOSAudioIODevice::getHostTempo()
    {
        float tempo = 120.0;
        
        if (isHostConnectedViaIAA())
        {
            HostCallbackInfo hostCallbackInfo;
            UInt32 dataSize = sizeof(HostCallbackInfo);
            OSStatus result = AudioUnitGetProperty(audioUnit, kAudioUnitProperty_HostCallbacks, kAudioUnitScope_Global, 0, &hostCallbackInfo, &dataSize);
            
            if (result == noErr)
            {
                Float64 outCurrentBeat = 0;
                Float64 outCurrentTempo = 0;
                void* hostUserData = hostCallbackInfo.hostUserData;
                
                OSStatus result = hostCallbackInfo.beatAndTempoProc(hostUserData, &outCurrentBeat, &outCurrentTempo);
                
                if (result == noErr)
                    tempo = outCurrentTempo;
                else
                    NSLog(@"Error occured fetching callBackInfo->beatAndTempoProc : %d", (int)result);
            }
        }
        
        return tempo;
    }
    
    void iOSAudioIODevice::getHostPlayHeadPositionInfo(double* ppqPosition, double* ppqPositionOfLastBarStart)
    {
        if (isHostConnectedViaIAA())
        {
            HostCallbackInfo hostCallbackInfo;
            UInt32 dataSize = sizeof(HostCallbackInfo);
            OSStatus result = AudioUnitGetProperty(audioUnit, kAudioUnitProperty_HostCallbacks, kAudioUnitScope_Global, 0, &hostCallbackInfo, &dataSize);
            
            if (result == noErr)
            {
                UInt32 outDeltaSampleOffsetToNextBeat = 0;
                Float32 outTimeSig_Numerator = 4.0;
                UInt32 outTimeSig_Denominator = 4;
                Float64 outCurrentMeasureDownBeat = 0.0;
                void* hostUserData = hostCallbackInfo.hostUserData;
                
                OSStatus result =  hostCallbackInfo.musicalTimeLocationProc(hostUserData,
                                                                            &outDeltaSampleOffsetToNextBeat,
                                                                            &outTimeSig_Numerator,
                                                                            &outTimeSig_Denominator,
                                                                            &outCurrentMeasureDownBeat);
                
                if (result == noErr)
                {
                    *ppqPositionOfLastBarStart = outCurrentMeasureDownBeat;
                    
                    Float64 outCurrentBeat = 0;
                    Float64 outCurrentTempo = 0;
                    void* hostUserData = hostCallbackInfo.hostUserData;
                    
                    OSStatus result = hostCallbackInfo.beatAndTempoProc(hostUserData, &outCurrentBeat, &outCurrentTempo);
                    
                    if (result == noErr)
                    {
                        *ppqPosition = outCurrentBeat;
                    }
                    else
                        NSLog(@"Error occured fetching callBackInfo->beatAndTempoProc : %d", (int)result);
                    
                }
                else
                    NSLog(@"Error occured fetching callBackInfo->musicalTimeLocationProc : %d", (int)result);
            }
            
        }
        
    }
    
    bool iOSAudioIODevice::isHostConnectedViaIAA()
    {
        if (audioUnit != 0)
        {
            if ([[Wrapper sharedInstance] isHostConnectedViaAudiobus])
                return false;
            
            UInt32 connect;
            UInt32 dataSize = sizeof(UInt32);
            AudioUnitGetProperty(audioUnit, kAudioUnitProperty_IsInterAppConnected, kAudioUnitScope_Global, 0, &connect, &dataSize);
            
            return connect;
        }
        
        return false;
    }
    
    void iOSAudioIODevice::updateAudioEngineState()
    {
        [[Wrapper sharedInstance] updateAudioEngineState];
    }
    
    void iOSAudioIODevice::prepareFloatBuffers (int bufferSize)
    {
        if (numInputChannels + numOutputChannels > 0)
        {
            floatData.setSize (numInputChannels + numOutputChannels, bufferSize);
            zeromem (inputChannels, sizeof (inputChannels));
            zeromem (outputChannels, sizeof (outputChannels));
            
            for (int i = 0; i < numInputChannels; ++i)
                inputChannels[i] = floatData.getWritePointer (i);
            
            for (int i = 0; i < numOutputChannels; ++i)
                outputChannels[i] = floatData.getWritePointer (i + numInputChannels);
        }
    }
    
    //==================================================================================================
    OSStatus iOSAudioIODevice::process (AudioUnitRenderActionFlags* flags, const AudioTimeStamp* time,
                                        const UInt32 numFrames, AudioBufferList* data)
    {
        OSStatus err = noErr;
        
        if (audioInputIsAvailable && numInputChannels > 0)
            err = AudioUnitRender (audioUnit, flags, time, 1, numFrames, data);
        
        const ScopedLock sl (callbackLock);
        
        if (callback != nullptr)
        {
            if ((int) numFrames > floatData.getNumSamples())
                prepareFloatBuffers ((int) numFrames);
            
            if (audioInputIsAvailable && numInputChannels > 0)
            {
                short* shortData = (short*) data->mBuffers[0].mData;
                
                if (numInputChannels >= 2)
                {
                    for (UInt32 i = 0; i < numFrames; ++i)
                    {
                        inputChannels[0][i] = *shortData++ * (1.0f / 32768.0f);
                        inputChannels[1][i] = *shortData++ * (1.0f / 32768.0f);
                    }
                }
                else
                {
                    if (monoInputChannelNumber > 0)
                        ++shortData;
                    
                    for (UInt32 i = 0; i < numFrames; ++i)
                    {
                        inputChannels[0][i] = *shortData++ * (1.0f / 32768.0f);
                        ++shortData;
                    }
                }
            }
            else
            {
                for (int i = numInputChannels; --i >= 0;)
                    zeromem (inputChannels[i], sizeof (float) * numFrames);
            }
            
            callback->audioDeviceIOCallback ((const float**) inputChannels, numInputChannels,
                                             outputChannels, numOutputChannels, (int) numFrames);
            
            short* shortData = (short*) data->mBuffers[0].mData;
            int n = 0;
            
            if (numOutputChannels >= 2)
            {
                for (UInt32 i = 0; i < numFrames; ++i)
                {
                    shortData [n++] = (short) (outputChannels[0][i] * 32767.0f);
                    shortData [n++] = (short) (outputChannels[1][i] * 32767.0f);
                }
            }
            else if (numOutputChannels == 1)
            {
                for (UInt32 i = 0; i < numFrames; ++i)
                {
                    const short s = (short) (outputChannels[monoOutputChannelNumber][i] * 32767.0f);
                    shortData [n++] = s;
                    shortData [n++] = s;
                }
            }
            else
            {
                zeromem (data->mBuffers[0].mData, 2 * sizeof (short) * numFrames);
            }
        }
        else
        {
            zeromem (data->mBuffers[0].mData, 2 * sizeof (short) * numFrames);
        }
        
        return err;
    }
    
    void iOSAudioIODevice::updateDeviceInfo()
    {
        // NEW
        sampleRate = [AVAudioSession sharedInstance].sampleRate;
        audioInputIsAvailable = [AVAudioSession sharedInstance].inputAvailable;
        
        // OLD
        //getSessionProperty (kAudioSessionProperty_CurrentHardwareSampleRate, sampleRate);
        //getSessionProperty (kAudioSessionProperty_AudioInputAvailable, audioInputIsAvailable);
    }
    
    void iOSAudioIODevice::updateCurrentBufferSize()
    {
        Float32 bufferDuration = sampleRate > 0 ? (Float32) (preferredBufferSize / sampleRate) : 0.0f;
        
        // NEW
        bufferDuration = [AVAudioSession sharedInstance].IOBufferDuration;
        
        // OLD
        //getSessionProperty (kAudioSessionProperty_CurrentHardwareIOBufferDuration, bufferDuration);
        
        actualBufferSize = (int) (sampleRate * bufferDuration + 0.5);
    }
    
    // OLD
    /*
     void iOSAudioIODevice::routingChanged (const void* propertyValue)
     {
     if (! isRunning)
     return;
     
     if (propertyValue != nullptr)
     {
     CFDictionaryRef routeChangeDictionary = (CFDictionaryRef) propertyValue;
     CFNumberRef routeChangeReasonRef = (CFNumberRef) CFDictionaryGetValue (routeChangeDictionary,
     CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
     
     SInt32 routeChangeReason;
     CFNumberGetValue (routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
     
     if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable)
     {
     const ScopedLock sl (callbackLock);
     
     if (callback != nullptr)
     callback->audioDeviceError ("Old device unavailable");
     }
     }
     
     updateDeviceInfo();
     createAudioUnit();
     
     AudioSessionSetActive (true);
     
     if (audioUnit != 0)
     {
     UInt32 formatSize = sizeof (format);
     AudioUnitGetProperty (audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &format, &formatSize);
     
     updateCurrentBufferSize();
     AudioOutputUnitStart (audioUnit);
     }
     }
     */
    
    void iOSAudioIODevice::setAudioUnitCallback(bool isEnabled)
    {
        AURenderCallbackStruct inputProc;
        
        if (isEnabled)
        {
            inputProc.inputProc = processStatic;
            inputProc.inputProcRefCon = this;
        }
        else
        {
            inputProc.inputProc = nullptr;
            inputProc.inputProcRefCon = nullptr;
        }
        
        AudioUnitSetProperty (audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inputProc, sizeof (inputProc));
    }
    
    void iOSAudioIODevice::interruptionListener (const UInt32 interruptionType)
    {
        if (interruptionType == kAudioSessionBeginInterruption)
        {
            isRunning = false;
            AudioOutputUnitStop (audioUnit);
            
            // NEW
            [[AVAudioSession sharedInstance] setActive: NO error:&err];
            
            // OLD
            //AudioSessionSetActive (false);
            
            const ScopedLock sl (callbackLock);
            
            if (callback != nullptr)
                callback->audioDeviceError ("iOS audio session interruption");
        }
        
        if (interruptionType == kAudioSessionEndInterruption)
        {
            isRunning = true;
            
            // NEW
            [[AVAudioSession sharedInstance] setActive: YES error:&err];
            
            // OLD
            //AudioSessionSetActive (true);
            
            AudioOutputUnitStart (audioUnit);
            
            const ScopedLock sl (callbackLock);
            
            if (callback != nullptr)
                callback->audioDeviceError ("iOS audio session resumed");
        }
    }
    
    
    //==================================================================================================
    void iOSAudioIODevice::resetFormat (const int numChannels) noexcept
    {
        zerostruct (format);
        format.mFormatID = kAudioFormatLinearPCM;
        format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
        format.mBitsPerChannel = 8 * sizeof (short);
        format.mChannelsPerFrame = (UInt32) numChannels;
        format.mFramesPerPacket = 1;
        format.mBytesPerFrame = format.mBytesPerPacket = (UInt32) numChannels * sizeof (short);
    }
    
    bool iOSAudioIODevice::createAudioUnit()
    {
        //OLD
        /*
         if (audioUnit != 0)
         {
         AudioComponentInstanceDispose (audioUnit);
         audioUnit = 0;
         }
         */
        
        resetFormat (2);
        
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        
        AudioComponent comp = AudioComponentFindNext (0, &desc);
        AudioComponentInstanceNew (comp, &audioUnit);
        
        if (audioUnit == 0)
            return false;
        
        if (numInputChannels > 0)
        {
            const UInt32 one = 1;
            AudioUnitSetProperty (audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof (one));
        }
        
        {
            AudioChannelLayout layout;
            layout.mChannelBitmap = 0;
            layout.mNumberChannelDescriptions = 0;
            layout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
            AudioUnitSetProperty (audioUnit, kAudioUnitProperty_AudioChannelLayout, kAudioUnitScope_Input,  0, &layout, sizeof (layout));
            AudioUnitSetProperty (audioUnit, kAudioUnitProperty_AudioChannelLayout, kAudioUnitScope_Output, 0, &layout, sizeof (layout));
        }
        
        {
            // NEW
            setAudioUnitCallback(true);
            
            // OLD
            /*
             AURenderCallbackStruct inputProc;
             inputProc.inputProc = processStatic;
             inputProc.inputProcRefCon = this;
             AudioUnitSetProperty (audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inputProc, sizeof (inputProc));
             */
        }
        
        AudioUnitSetProperty (audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,  0, &format, sizeof (format));
        AudioUnitSetProperty (audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &format, sizeof (format));
        
        AudioUnitInitialize (audioUnit);
        
        // AB
        [[Wrapper sharedInstance] activateAudiobus: audioUnit];
        
        return true;
    }
    
    // OLD
    /*
     // If the routing is set to go through the receiver (i.e. the speaker, but quiet), this re-routes it
     // to make it loud. Needed because by default when using an input + output, the output is kept quiet.
     void iOSAudioIODevice::fixAudioRouteIfSetToReceiver()
     {
     CFStringRef audioRoute = 0;
     if (getSessionProperty (kAudioSessionProperty_AudioRoute, audioRoute) == noErr)
     {
     NSString* route = (NSString*) audioRoute;
     
     //DBG ("audio route: " + nsStringToJuce (route));
     
     if ([route hasPrefix: @"Receiver"])
     setSessionUInt32Property (kAudioSessionProperty_OverrideAudioRoute, kAudioSessionOverrideAudioRoute_Speaker);
     
     CFRelease (audioRoute);
     }
     }
     */
    
    //==============================================================================
    class iOSAudioIODeviceType  : public AudioIODeviceType
    {
    public:
        iOSAudioIODeviceType()  : AudioIODeviceType ("iOS Audio") {}
        
        void scanForDevices() {}
        StringArray getDeviceNames (bool /*wantInputNames*/) const       { return StringArray ("iOS Audio"); }
        int getDefaultDeviceIndex (bool /*forInput*/) const              { return 0; }
        int getIndexOfDevice (AudioIODevice* d, bool /*asInput*/) const  { return d != nullptr ? 0 : -1; }
        bool hasSeparateInputsAndOutputs() const                         { return false; }
        
        AudioIODevice* createDevice (const String& outputDeviceName, const String& inputDeviceName)
        {
            if (outputDeviceName.isNotEmpty() || inputDeviceName.isNotEmpty())
                return new iOSAudioIODevice (outputDeviceName.isNotEmpty() ? outputDeviceName
                                             : inputDeviceName);
            
            return nullptr;
        }
        
    private:
        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (iOSAudioIODeviceType)
    };
    
    //==============================================================================
    AudioIODeviceType* AudioIODeviceType::createAudioIODeviceType_iOSAudio()
    {
        return new iOSAudioIODeviceType();
    }
    No newline at end of file
