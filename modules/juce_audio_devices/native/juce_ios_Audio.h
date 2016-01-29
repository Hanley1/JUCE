//
//  juce_ios_Audio.h
//  Syntorial
//
//  Created by Joe Hanley on 2/4/15.
//
//

#ifndef Syntorial_juce_ios_Audio_h
#define Syntorial_juce_ios_Audio_h

class iOSAudioIODevice  : public AudioIODevice
{
public:
    iOSAudioIODevice (const String& deviceName);
    ~iOSAudioIODevice();
    
    StringArray getOutputChannelNames() override;
    StringArray getInputChannelNames() override;
    
    Array<double> getAvailableSampleRates() override;
    
    Array<int> getAvailableBufferSizes() override;
    
    int getDefaultBufferSize() override;
    
    String open (const BigInteger& inputChannelsWanted,
                 const BigInteger& outputChannelsWanted,
                 double targetSampleRate, int bufferSize) override;
    
    void close() override;
    
    bool isOpen() override;
    
    int getCurrentBufferSizeSamples() override;
    double getCurrentSampleRate() override;
    int getCurrentBitDepth() override;
    
    BigInteger getActiveOutputChannels() const override;
    BigInteger getActiveInputChannels() const override;
    
    int getOutputLatencyInSamples() override;
    int getInputLatencyInSamples() override;
    
    // OLD
    //int getLatency (AudioSessionPropertyID propID);
    
    void start (AudioIODeviceCallback* newCallback) override;
    
    void stop() override;
    
    bool isPlaying() override;
    String getLastError() override;
    
    bool setAudioPreprocessingEnabled (bool enable) override;
    
    // NEW
    void routingChanged (const NSNotification* notification);
    void closeAudioUnit();
    void stopAudioUnit();
    void startAudioUnit();
    AudioUnit getAudioUnit() {return audioUnit;}
    void toggleHostPlayback();
    void toggleHostRecord();
    void toggleHostRewind();
    void* getHostIcon();
    void goToHost();
    void getHostTransportInfo(bool* isPlaying, bool* isRecording, String* playTime);
    float getHostTempo();
    void getHostPlayHeadPositionInfo(double* ppqPosition, double* ppqPositionOfLastBarStart);
    bool isHostConnectedViaIAA();
    static void updateAudioEngineState();
    
    void setAudioUnitCallback(bool isEnabled);
    
private:
    //==================================================================================================
    
    // NEW
    NSError* err;
    
    CriticalSection callbackLock;
    Float64 sampleRate;
    int numInputChannels, numOutputChannels;
    int preferredBufferSize, actualBufferSize;
    bool isRunning;
    String lastError;
    
    AudioStreamBasicDescription format;
    static AudioUnit audioUnit;
    UInt32 audioInputIsAvailable;
    AudioIODeviceCallback* callback;
    BigInteger activeOutputChans, activeInputChans;
    
    AudioSampleBuffer floatData;
    float* inputChannels[3];
    float* outputChannels[3];
    bool monoInputChannelNumber, monoOutputChannelNumber;
    
    void prepareFloatBuffers (int bufferSize);
    
    //==================================================================================================
    OSStatus process (AudioUnitRenderActionFlags* flags, const AudioTimeStamp* time,
                      const UInt32 numFrames, AudioBufferList* data);
    
    void updateDeviceInfo();
    
    void updateCurrentBufferSize();
    
    // OLD
    //void routingChanged (const void* propertyValue);
    
    //==================================================================================================
    struct AudioSessionHolder
    {
        AudioSessionHolder()
        {
            // OLD
            //AudioSessionInitialize (0, 0, interruptionListenerCallback, this);
        }
        
        static void interruptionListenerCallback (void* client, UInt32 interruptionType)
        {
            const Array <iOSAudioIODevice*>& activeDevices = static_cast <AudioSessionHolder*> (client)->activeDevices;
            
            for (int i = activeDevices.size(); --i >= 0;)
                activeDevices.getUnchecked(i)->interruptionListener (interruptionType);
        }
        
        Array <iOSAudioIODevice*> activeDevices;
    };
    
    static AudioSessionHolder& getSessionHolder()
    {
        static AudioSessionHolder audioSessionHolder;
        return audioSessionHolder;
    }
    
    void interruptionListener (const UInt32 interruptionType);
    
    //==================================================================================================
    static OSStatus processStatic (void* client, AudioUnitRenderActionFlags* flags, const AudioTimeStamp* time,
                                   UInt32 /*busNumber*/, UInt32 numFrames, AudioBufferList* data)
    {
        return static_cast<iOSAudioIODevice*> (client)->process (flags, time, numFrames, data);
    }
    
    // OLD
    //static void routingChangedStatic (void* client, AudioSessionPropertyID, UInt32 /*inDataSize*/, const void* propertyValue)
    //{
    //   static_cast<iOSAudioIODevice*> (client)->routingChanged (propertyValue);
    //}
    
    //==================================================================================================
    void resetFormat (const int numChannels) noexcept;
    
    bool createAudioUnit();
    
    // OLD
    /*
    // If the routing is set to go through the receiver (i.e. the speaker, but quiet), this re-routes it
    // to make it loud. Needed because by default when using an input + output, the output is kept quiet.
    static void fixAudioRouteIfSetToReceiver();
    
    template <typename Type>
    static OSStatus getSessionProperty (AudioSessionPropertyID propID, Type& result) noexcept
    {
        UInt32 valueSize = sizeof (result);
        return AudioSessionGetProperty (propID, &valueSize, &result);
    }
    
    static bool setSessionUInt32Property  (AudioSessionPropertyID propID, UInt32  v) noexcept  { return AudioSessionSetProperty (propID, sizeof (v), &v) == kAudioSessionNoError; }
    static bool setSessionFloat32Property (AudioSessionPropertyID propID, Float32 v) noexcept  { return AudioSessionSetProperty (propID, sizeof (v), &v) == kAudioSessionNoError; }
    static bool setSessionFloat64Property (AudioSessionPropertyID propID, Float64 v) noexcept  { return AudioSessionSetProperty (propID, sizeof (v), &v) == kAudioSessionNoError; }
    */
    
    JUCE_DECLARE_NON_COPYABLE (iOSAudioIODevice)
};


#endif
