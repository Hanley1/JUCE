/*
  ==============================================================================

   This file is part of the JUCE library.
   Copyright (c) 2015 - ROLI Ltd.

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

#if JUCE_IOS
 using BaseClass = UIViewComponent;
#else
 using BaseClass = NSViewComponent;
#endif

struct VideoComponent::Pimpl   : public BaseClass
{
    Pimpl()
    {
        setVisible (true);

       #if JUCE_MAC && JUCE_32BIT
        auto view = [[NSView alloc] init];  // 32-bit builds don't have AVPlayerView, so need to use a layer
        controller = [[AVPlayerLayer alloc] init];
        // pch 1/15/18 gets rid of internal slider on videos
//        controller.controlsStyle = AVPlayerViewControlsStyleNone;
        setView (view);
        [view setNextResponder: [view superview]];
        [view setWantsLayer: YES];
        [view setLayer: controller];
        [view release];
       #elif JUCE_MAC
        controller = [[MyAVPlayerView alloc] init];
        // pch 1/15/18 gets rid of internal slider on videos
        controller.controlsStyle = AVPlayerViewControlsStyleNone;
        setView (controller);
        [controller setNextResponder: [controller superview]];
        [controller setWantsLayer: YES];
       #else
        controller = [[AVPlayerViewController alloc] init];
        // pch 1/15/18 gets rid of internal slider on videos
        controller.showsPlaybackControls = false;
        setView ([controller view]);
       #endif
    }

    ~Pimpl()
    {
        close();
        setView (nil);
        [controller release];
    }
    
    void showPlaybackControls(bool show)
    {
#if JUCE_IOS
        controller.showsPlaybackControls = show;
#else
        
#ifndef IS_PRIMER
        if (show)
            controller.controlsStyle = AVPlayerViewControlsStyleInline;
        else
            controller.controlsStyle = AVPlayerViewControlsStyleNone;
#endif
#endif
        
    }

    Result load (const File& file)
    {
        auto r = load (createNSURLFromFile (file));

        if (r.wasOk())
            currentFile = file;

        return r;
    }

    Result load (const URL& url)
    {
        auto r = load ([NSURL URLWithString: juceStringToNS (url.toString (true))]);

        if (r.wasOk())
            currentURL = url;

        return r;
    }

    Result load (NSURL* url)
    {
        if (url != nil)
        {
            close();

            if (auto* player = [AVPlayer playerWithURL: url])
            {
                [controller setPlayer: player];
                return Result::ok();
            }
        }

        return Result::fail ("Couldn't open movie");
    }

    void close()
    {
        stop();
        [controller setPlayer: nil];
        currentFile = File();
        currentURL = {};
    }

    bool isOpen() const noexcept        { return getAVPlayer() != nil; }
    bool isPlaying() const noexcept     { return getSpeed() != 0; }

    void play() noexcept                { [getAVPlayer() play]; }
    void stop() noexcept                { [getAVPlayer() pause]; }

    void setPosition (double newPosition)
    {
        if (auto* p = getAVPlayer())
        {
            CMTime t = { (CMTimeValue) (100000.0 * newPosition),
                         (CMTimeScale) 100000, kCMTimeFlags_Valid };

            [p seekToTime: t
          toleranceBefore: kCMTimeZero
           toleranceAfter: kCMTimeZero];
        }
    }

    double getPosition() const
    {
        if (auto* p = getAVPlayer())
            return toSeconds ([p currentTime]);

        return 0.0;
    }

    void setSpeed (double newSpeed)
    {
        [getAVPlayer() setRate: (float) newSpeed];
    }

    double getSpeed() const
    {
        if (auto* p = getAVPlayer())
            return [p rate];

        return 0.0;
    }

    Rectangle<int> getNativeSize() const
    {
        if (auto* player = getAVPlayer())
        {
            auto s = [[player currentItem] presentationSize];
            return { (int) s.width, (int) s.height };
        }

        return {};
    }

    double getDuration() const
    {
        if (auto* player = getAVPlayer())
            return toSeconds ([[player currentItem] duration]);

        return 0.0;
    }

    void setVolume (float newVolume)
    {
        [getAVPlayer() setVolume: newVolume];
    }

    float getVolume() const
    {
        if (auto* p = getAVPlayer())
            return [p volume];

        return 0.0f;
    }

    File currentFile;
    URL currentURL;

private:
//<<<<<<< HEAD
   #if JUCE_IOS
    AVPlayerViewController* controller = nil;
   #elif JUCE_32BIT
    AVPlayerLayer* controller = nil;
//=======
//    //==============================================================================
//    template <typename Derived>
//    class PlayerControllerBase
//    {
//    public:
//        ~PlayerControllerBase()
//        {
//            detachPlayerStatusObserver();
//            detachPlaybackObserver();
//        }
//
//    protected:
//        //==============================================================================
//        struct JucePlayerStatusObserverClass : public ObjCClass<NSObject>
//        {
//            JucePlayerStatusObserverClass()    : ObjCClass<NSObject> ("JucePlayerStatusObserverClass_")
//            {
//               #pragma clang diagnostic push
//               #pragma clang diagnostic ignored "-Wundeclared-selector"
//                addMethod (@selector (observeValueForKeyPath:ofObject:change:context:), valueChanged, "v@:@@@?");
//               #pragma clang diagnostic pop
//
//                addIvar<PlayerAsyncInitialiser*> ("owner");
//
//                registerClass();
//            }
//
//            //==============================================================================
//            static PlayerControllerBase& getOwner (id self) { return *getIvar<PlayerControllerBase*> (self, "owner"); }
//            static void setOwner (id self, PlayerControllerBase* p) { object_setInstanceVariable (self, "owner", p); }
//
//        private:
//            static void valueChanged (id self, SEL, NSString* keyPath, id,
//                                      NSDictionary<NSKeyValueChangeKey, id>* change, void*)
//            {
//                auto& owner = getOwner (self);
//
//                if ([keyPath isEqualToString: nsStringLiteral ("rate")])
//                {
//                    auto oldRate = [change[NSKeyValueChangeOldKey] floatValue];
//                    auto newRate = [change[NSKeyValueChangeNewKey] floatValue];
//
//                    if (oldRate == 0 && newRate != 0)
//                        owner.playbackStarted();
//                    else if (oldRate != 0 && newRate == 0)
//                        owner.playbackStopped();
//                }
//                else if ([keyPath isEqualToString: nsStringLiteral ("status")])
//                {
//                    auto status = [change[NSKeyValueChangeNewKey] intValue];
//
//                    if (status == AVPlayerStatusFailed)
//                        owner.errorOccurred();
//                }
//            }
//        };
//
//        //==============================================================================
//        struct JucePlayerItemPlaybackStatusObserverClass : public ObjCClass<NSObject>
//        {
//            JucePlayerItemPlaybackStatusObserverClass()    : ObjCClass<NSObject> ("JucePlayerItemPlaybackStatusObserverClass_")
//            {
//               #pragma clang diagnostic push
//               #pragma clang diagnostic ignored "-Wundeclared-selector"
//                addMethod (@selector (processNotification:), notificationReceived, "v@:@");
//               #pragma clang diagnostic pop
//
//                addIvar<PlayerControllerBase*> ("owner");
//
//                registerClass();
//            }
//
//            //==============================================================================
//            static PlayerControllerBase& getOwner (id self) { return *getIvar<PlayerControllerBase*> (self, "owner"); }
//            static void setOwner (id self, PlayerControllerBase* p) { object_setInstanceVariable (self, "owner", p); }
//
//        private:
//            static void notificationReceived (id self, SEL, NSNotification* notification)
//            {
//                if ([notification.name isEqualToString: AVPlayerItemDidPlayToEndTimeNotification])
//                    getOwner (self).playbackReachedEndTime();
//            }
//        };
//
//        //==============================================================================
//        class PlayerAsyncInitialiser
//        {
//        public:
//            PlayerAsyncInitialiser (PlayerControllerBase& ownerToUse)
//                : owner (ownerToUse),
//                  assetKeys ([[NSArray alloc] initWithObjects: nsStringLiteral ("duration"), nsStringLiteral ("tracks"),
//                                                               nsStringLiteral ("playable"), nil])
//            {
//                static JucePlayerItemPreparationStatusObserverClass cls;
//                playerItemPreparationStatusObserver.reset ([cls.createInstance() init]);
//                JucePlayerItemPreparationStatusObserverClass::setOwner (playerItemPreparationStatusObserver.get(), this);
//            }
//
//            ~PlayerAsyncInitialiser()
//            {
//                detachPreparationStatusObserver();
//            }
//
//            void loadAsync (URL url)
//            {
//                auto nsUrl = [NSURL URLWithString: juceStringToNS (url.toString (true))];
//                asset.reset ([[AVURLAsset alloc] initWithURL: nsUrl options: nil]);
//
//                [asset.get() loadValuesAsynchronouslyForKeys: assetKeys.get()
//                                           completionHandler: ^() { checkAllKeysReadyFor (asset.get(), url); }];
//            }
//
//        private:
//            //==============================================================================
//            struct JucePlayerItemPreparationStatusObserverClass : public ObjCClass<NSObject>
//            {
//                JucePlayerItemPreparationStatusObserverClass()    : ObjCClass<NSObject> ("JucePlayerItemStatusObserverClass_")
//                {
//                   #pragma clang diagnostic push
//                   #pragma clang diagnostic ignored "-Wundeclared-selector"
//                    addMethod (@selector (observeValueForKeyPath:ofObject:change:context:), valueChanged, "v@:@@@?");
//                   #pragma clang diagnostic pop
//
//                    addIvar<PlayerAsyncInitialiser*> ("owner");
//
//                    registerClass();
//                }
//
//                //==============================================================================
//                static PlayerAsyncInitialiser& getOwner (id self) { return *getIvar<PlayerAsyncInitialiser*> (self, "owner"); }
//                static void setOwner (id self, PlayerAsyncInitialiser* p) { object_setInstanceVariable (self, "owner", p); }
//
//            private:
//                static void valueChanged (id self, SEL, NSString*, id object,
//                                          NSDictionary<NSKeyValueChangeKey, id>* change, void* context)
//                {
//                    auto& owner = getOwner (self);
//
//                    if (context == &owner)
//                    {
//                        auto* playerItem = (AVPlayerItem*) object;
//                        auto* urlAsset = (AVURLAsset*) playerItem.asset;
//
//                        URL url (nsStringToJuce (urlAsset.URL.absoluteString));
//                        auto oldStatus = [change[NSKeyValueChangeOldKey] intValue];
//                        auto newStatus = [change[NSKeyValueChangeNewKey] intValue];
//
//                        // Ignore spurious notifications
//                        if (oldStatus == newStatus)
//                            return;
//
//                        if (newStatus == AVPlayerItemStatusFailed)
//                        {
//                            auto errorMessage = playerItem.error != nil
//                                              ? nsStringToJuce (playerItem.error.localizedDescription)
//                                              : String();
//
//                            owner.notifyOwnerPreparationFinished (url, Result::fail (errorMessage), nullptr);
//                        }
//                        else if (newStatus == AVPlayerItemStatusReadyToPlay)
//                        {
//                            owner.notifyOwnerPreparationFinished (url, Result::ok(), owner.player.release());
//                        }
//                        else
//                        {
//                            jassertfalse;
//                        }
//                    }
//                }
//            };
//
//            //==============================================================================
//            PlayerControllerBase& owner;
//
//            std::unique_ptr<AVURLAsset, NSObjectDeleter> asset;
//            std::unique_ptr<NSArray<NSString*>, NSObjectDeleter> assetKeys;
//            std::unique_ptr<AVPlayerItem, NSObjectDeleter> playerItem;
//            std::unique_ptr<NSObject, NSObjectDeleter> playerItemPreparationStatusObserver;
//            std::unique_ptr<AVPlayer, NSObjectDeleter> player;
//
//            //==============================================================================
//            void checkAllKeysReadyFor (AVAsset* assetToCheck, const URL& url)
//            {
//                NSError* error = nil;
//
//                int successCount = 0;
//
//                for (NSString* key : assetKeys.get())
//                {
//                    switch ([assetToCheck statusOfValueForKey: key error: &error])
//                    {
//                        case AVKeyValueStatusLoaded:
//                        {
//                            ++successCount;
//                            break;
//                        }
//                        case AVKeyValueStatusCancelled:
//                        {
//                            notifyOwnerPreparationFinished (url, Result::fail ("Loading cancelled"), nullptr);
//                            return;
//                        }
//                        case AVKeyValueStatusFailed:
//                        {
//                            auto errorMessage = error != nil ? nsStringToJuce (error.localizedDescription) : String();
//                            notifyOwnerPreparationFinished (url, Result::fail (errorMessage), nullptr);
//                            return;
//                        }
//                        default:
//                        {}
//                    }
//                }
//
//                jassert (successCount == (int) [assetKeys.get() count]);
//                preparePlayerItem();
//            }
//
//            void preparePlayerItem()
//            {
//                playerItem.reset ([[AVPlayerItem alloc] initWithAsset: asset.get()]);
//
//                attachPreparationStatusObserver();
//
//                player.reset ([[AVPlayer alloc] initWithPlayerItem: playerItem.get()]);
//            }
//
//            //==============================================================================
//            void attachPreparationStatusObserver()
//            {
//                [playerItem.get() addObserver: playerItemPreparationStatusObserver.get()
//                                   forKeyPath: nsStringLiteral ("status")
//                                      options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
//                                      context: this];
//            }
//
//            void detachPreparationStatusObserver()
//            {
//                if (playerItem != nullptr && playerItemPreparationStatusObserver != nullptr)
//                {
//                    [playerItem.get() removeObserver: playerItemPreparationStatusObserver.get()
//                                          forKeyPath: nsStringLiteral ("status")
//                                             context: this];
//                }
//            }
//
//            //==============================================================================
//            void notifyOwnerPreparationFinished (const URL& url, Result r, AVPlayer* preparedPlayer)
//            {
//                WeakReference<PlayerAsyncInitialiser> safeThis (this);
//
//                MessageManager::callAsync ([safeThis, url, r, preparedPlayer]() mutable
//                {
//                    if (safeThis != nullptr)
//                        safeThis->owner.playerPreparationFinished (url, r, preparedPlayer);
//                });
//            }
//
//            JUCE_DECLARE_WEAK_REFERENCEABLE (PlayerAsyncInitialiser)
//        };
//
//        //==============================================================================
//        Pimpl& owner;
//        bool useNativeControls;
//
//        PlayerAsyncInitialiser playerAsyncInitialiser;
//        std::unique_ptr<NSObject, NSObjectDeleter> playerStatusObserver;
//        std::unique_ptr<NSObject, NSObjectDeleter> playerItemPlaybackStatusObserver;
//
//        //==============================================================================
//        PlayerControllerBase (Pimpl& ownerToUse, bool useNativeControlsIfAvailable)
//            : owner (ownerToUse),
//              useNativeControls (useNativeControlsIfAvailable),
//              playerAsyncInitialiser (*this)
//        {
//            static JucePlayerStatusObserverClass playerObserverClass;
//            playerStatusObserver.reset ([playerObserverClass.createInstance() init]);
//            JucePlayerStatusObserverClass::setOwner (playerStatusObserver.get(), this);
//
//            static JucePlayerItemPlaybackStatusObserverClass itemObserverClass;
//            playerItemPlaybackStatusObserver.reset ([itemObserverClass.createInstance() init]);
//            JucePlayerItemPlaybackStatusObserverClass::setOwner (playerItemPlaybackStatusObserver.get(), this);
//        }
//
//        //==============================================================================
//        void attachPlayerStatusObserver()
//        {
//            [crtp().getPlayer() addObserver: playerStatusObserver.get()
//                                 forKeyPath: nsStringLiteral ("rate")
//                                    options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
//                                    context: this];
//
//            [crtp().getPlayer() addObserver: playerStatusObserver.get()
//                                 forKeyPath: nsStringLiteral ("status")
//                                    options: NSKeyValueObservingOptionNew
//                                    context: this];
//        }
//
//        void detachPlayerStatusObserver()
//        {
//            if (crtp().getPlayer() != nullptr && playerStatusObserver != nullptr)
//            {
//                    [crtp().getPlayer() removeObserver: playerStatusObserver.get()
//                                            forKeyPath: nsStringLiteral ("rate")
//                                               context: this];
//
//                    [crtp().getPlayer() removeObserver: playerStatusObserver.get()
//                                            forKeyPath: nsStringLiteral ("status")
//                                               context: this];
//            }
//        }
//
//        void attachPlaybackObserver()
//        {
//           #pragma clang diagnostic push
//           #pragma clang diagnostic ignored "-Wundeclared-selector"
//            [[NSNotificationCenter defaultCenter] addObserver: playerItemPlaybackStatusObserver.get()
//                                                     selector: @selector (processNotification:)
//                                                         name: AVPlayerItemDidPlayToEndTimeNotification
//                                                       object: [crtp().getPlayer() currentItem]];
//           #pragma clang diagnostic pop
//        }
//
//        void detachPlaybackObserver()
//        {
//           #pragma clang diagnostic push
//           #pragma clang diagnostic ignored "-Wundeclared-selector"
//            [[NSNotificationCenter defaultCenter] removeObserver: playerItemPlaybackStatusObserver.get()];
//           #pragma clang diagnostic pop
//        }
//
//    private:
//        //==============================================================================
//        Derived& crtp() { return static_cast<Derived&> (*this); }
//
//        //==============================================================================
//        void playerPreparationFinished (const URL& url, Result r, AVPlayer* preparedPlayer)
//        {
//            if (preparedPlayer != nil)
//                crtp().setPlayer (preparedPlayer);
//
//            owner.playerPreparationFinished (url, r);
//        }
//
//        void playbackReachedEndTime()
//        {
//            WeakReference<PlayerControllerBase> safeThis (this);
//
//            MessageManager::callAsync ([safeThis]() mutable
//                                       {
//                                           if (safeThis != nullptr)
//                                               safeThis->owner.playbackReachedEndTime();
//                                       });
//        }
//
//        //==============================================================================
//        void errorOccurred()
//        {
//            auto errorMessage = (crtp().getPlayer() != nil && crtp().getPlayer().error != nil)
//                              ? nsStringToJuce (crtp().getPlayer().error.localizedDescription)
//                              : String();
//
//            owner.errorOccurred (errorMessage);
//        }
//
//        void playbackStarted()
//        {
//            owner.playbackStarted();
//        }
//
//        void playbackStopped()
//        {
//            owner.playbackStopped();
//        }
//
//        JUCE_DECLARE_WEAK_REFERENCEABLE (PlayerControllerBase)
//    };
//
//   #if JUCE_MAC
//    //==============================================================================
//    class PlayerController  : public PlayerControllerBase<PlayerController>
//    {
//    public:
//        PlayerController (Pimpl& ownerToUse, bool useNativeControlsIfAvailable)
//            : PlayerControllerBase (ownerToUse, useNativeControlsIfAvailable)
//        {
//           #if JUCE_32BIT
//            // 32-bit builds don't have AVPlayerView, so need to use a layer
//            useNativeControls = false;
//           #endif
//
//            if (useNativeControls)
//            {
//               #if ! JUCE_32BIT
//                playerView = [[AVPlayerView alloc] init];
//               #endif
//            }
//            else
//            {
//                view = [[NSView alloc] init];
//                playerLayer = [[AVPlayerLayer alloc] init];
//                [view setLayer: playerLayer];
//            }
//        }
//
//        ~PlayerController()
//        {
//           #if JUCE_32BIT
//            [view release];
//            [playerLayer release];
//           #else
//            [playerView release];
//           #endif
//        }
//
//        NSView* getView()
//        {
//           #if ! JUCE_32BIT
//            if (useNativeControls)
//                return playerView;
//           #endif
//
//            return view;
//        }
//
//        Result load (NSURL* url)
//        {
//            if (auto player = [AVPlayer playerWithURL: url])
//            {
//                setPlayer (player);
//                return Result::ok();
//            }
//
//            return Result::fail ("Couldn't open movie");
//        }
//
//        void loadAsync (URL url)
//        {
//            playerAsyncInitialiser.loadAsync (url);
//        }
//
//        void close() { setPlayer (nil); }
//
//        void setPlayer (AVPlayer* player)
//        {
//           #if ! JUCE_32BIT
//            if (useNativeControls)
//            {
//                [playerView setPlayer: player];
//                attachPlayerStatusObserver();
//                attachPlaybackObserver();
//                return;
//            }
//           #endif
//
//            [playerLayer setPlayer: player];
//            attachPlayerStatusObserver();
//            attachPlaybackObserver();
//        }
//
//        AVPlayer* getPlayer() const
//        {
//           #if ! JUCE_32BIT
//            if (useNativeControls)
//                return [playerView player];
//           #endif
//
//            return [playerLayer player];
//        }
//
//    private:
//        NSView* view = nil;
//        AVPlayerLayer* playerLayer = nil;
//       #if ! JUCE_32BIT
//        // 32-bit builds don't have AVPlayerView
//        AVPlayerView* playerView = nil;
//       #endif
//    };
//>>>>>>> baf78b1e5f6e02ade4f209d7f45a60e43f9b53cd
   #else
    AVPlayerView* controller = nil;
   #endif

    AVPlayer* getAVPlayer() const noexcept   { return [controller player]; }

    static double toSeconds (const CMTime& t) noexcept
    {
        return t.timescale != 0 ? (t.value / (double) t.timescale) : 0.0;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Pimpl)
};
