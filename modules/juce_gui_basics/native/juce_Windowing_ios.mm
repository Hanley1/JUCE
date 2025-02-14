/*
  ==============================================================================

   This file is part of the JUCE framework.
   Copyright (c) Raw Material Software Limited

   JUCE is an open source framework subject to commercial or open source
   licensing.

   By downloading, installing, or using the JUCE framework, or combining the
   JUCE framework with any other source code, object code, content or any other
   copyrightable work, you agree to the terms of the JUCE End User Licence
   Agreement, and all incorporated terms including the JUCE Privacy Policy and
   the JUCE Website Terms of Service, as applicable, which will bind you. If you
   do not agree to the terms of these agreements, we will not license the JUCE
   framework to you, and you must discontinue the installation or download
   process and cease use of the JUCE framework.

   JUCE End User Licence Agreement: https://juce.com/legal/juce-8-licence/
   JUCE Privacy Policy: https://juce.com/juce-privacy-policy
   JUCE Website Terms of Service: https://juce.com/juce-website-terms-of-service/

   Or:

   You may also use this code under the terms of the AGPLv3:
   https://www.gnu.org/licenses/agpl-3.0.en.html

   THE JUCE FRAMEWORK IS PROVIDED "AS IS" WITHOUT ANY WARRANTY, AND ALL
   WARRANTIES, WHETHER EXPRESSED OR IMPLIED, INCLUDING WARRANTY OF
   MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, ARE DISCLAIMED.

  ==============================================================================
*/

namespace juce
{
    extern bool isIOSAppActive;

    struct AppInactivityCallback // NB: careful, this declaration is duplicated in other modules
    {
        virtual ~AppInactivityCallback() = default;
        virtual void appBecomingInactive() = 0;
    };

    // This is an internal list of callbacks (but currently used between modules)
    Array<AppInactivityCallback*> appBecomingInactiveCallbacks;
} // namespace juce

#if !IS_PRIMER && !SIMULATOR
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#endif

#if JUCE_PUSH_NOTIFICATIONS && defined (__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface JuceAppStartupDelegate : NSObject <UIApplicationDelegate, UNUserNotificationCenterDelegate>
#else
@interface JuceAppStartupDelegate : NSObject <UIApplicationDelegate>
#endif
{
    UIBackgroundTaskIdentifier appSuspendTask;
    std::optional<ScopedJuceInitialiser_GUI> initialiser;
}

@property (strong, nonatomic) UIWindow *window;
- (id) init;
- (void) dealloc;
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions ;
//- (void) applicationDidFinishLaunching: (UIApplication*) application;
- (void) applicationWillTerminate: (UIApplication*) application;
- (void) applicationDidEnterBackground: (UIApplication*) application;
- (void) applicationWillEnterForeground: (UIApplication*) application;
- (void) applicationDidBecomeActive: (UIApplication*) application;
- (void) applicationWillResignActive: (UIApplication*) application;
- (void) application: (UIApplication*) application handleEventsForBackgroundURLSession: (NSString*) identifier
   completionHandler: (void (^)(void)) completionHandler;
- (void) applicationDidReceiveMemoryWarning: (UIApplication *) application;
#if JUCE_PUSH_NOTIFICATIONS

- (void)                                 application: (UIApplication*) application
    didRegisterForRemoteNotificationsWithDeviceToken: (NSData*) deviceToken;
- (void)                                 application: (UIApplication*) application
    didFailToRegisterForRemoteNotificationsWithError: (NSError*) error;
- (void)                                 application: (UIApplication*) application
                        didReceiveRemoteNotification: (NSDictionary*) userInfo;
- (void)                                 application: (UIApplication*) application
                        didReceiveRemoteNotification: (NSDictionary*) userInfo
                              fetchCompletionHandler: (void (^)(UIBackgroundFetchResult result)) completionHandler;
- (void)                                 application: (UIApplication*) application
                          handleActionWithIdentifier: (NSString*) identifier
                               forRemoteNotification: (NSDictionary*) userInfo
                                    withResponseInfo: (NSDictionary*) responseInfo
                                   completionHandler: (void(^)()) completionHandler;

- (void) userNotificationCenter: (UNUserNotificationCenter*) center
        willPresentNotification: (UNNotification*) notification
          withCompletionHandler: (void (^)(UNNotificationPresentationOptions options)) completionHandler;
- (void) userNotificationCenter: (UNUserNotificationCenter*) center didReceiveNotificationResponse: (UNNotificationResponse*) response
          withCompletionHandler: (void(^)())completionHandler;
#endif
#endif

@end

@implementation JuceAppStartupDelegate

    NSObject* _pushNotificationsDelegate;

- (id) init
{
    self = [super init];
    appSuspendTask = UIBackgroundTaskInvalid;

   #if JUCE_PUSH_NOTIFICATIONS && defined (__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
   #endif

    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
#if !IS_PRIMER && !SIMULATOR
#if SPANISH
    [DBClientsManager setupWithAppKey:@"0gufsa8x5i9aan5"];
#else
    [DBClientsManager setupWithAppKey:@"fzmtyqfr3chhdbg"];
#endif
#endif

    NSObject* _pushNotificationsDelegate;

    ignoreUnused (application);
    initialiser.emplace();

    if (auto* app = JUCEApplicationBase::createInstance())
    {
        NSError* error = nil;
        
        // exclude Application Support/Resources folder from backup.
        
        NSURL *applicationSupportDirectory = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                                    inDomain:NSUserDomainMask
                                                                           appropriateForURL:nil
                                                                                      create:YES
                                                                                       error:&error];
        if (error)
            NSLog(@"KCDM: Could not create application support directory. %@", error);
        
        NSURL *resourcesFolder = [applicationSupportDirectory URLByAppendingPathComponent:@"Resources" isDirectory:YES];
        
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[resourcesFolder path]
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error])
        {
            NSLog(@"KCDM: Error creating Resources folder: %@", error);
        }
        
        BOOL success = [resourcesFolder setResourceValue:@YES forKey: NSURLIsExcludedFromBackupKey error: &error];
        
        if (!success)
            NSLog(@"KCDM: Error excluding %@ from backup %@", resourcesFolder, error);
        
        // register to observe notifications from the icloud key-value store
        [[NSNotificationCenter defaultCenter]
            addObserver: self
            selector: @selector (handleChangesFromiCloud:)
            name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
            object: [NSUbiquitousKeyValueStore defaultStore]];
        
        // get changes that might have happened while this instance of your app wasn't running
        [[NSUbiquitousKeyValueStore defaultStore] synchronize];
        
        if (! app->initialiseApp())
            exit (app->shutdownApp());
    }
    else
    {
        jassertfalse; // you must supply an application object for an iOS app!
    }
    
    return YES;
}

- (void) handleChangesFromiCloud: (NSNotification *) notification
{
    NSDictionary * userInfo = [notification userInfo];
    NSInteger reason = [[userInfo objectForKey:NSUbiquitousKeyValueStoreChangeReasonKey] integerValue];
    // 4 reasons:
    switch (reason) {
        case NSUbiquitousKeyValueStoreServerChange:
            // Updated values
            break;
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            // First launch
            break;
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            // No free space
            break;
        case NSUbiquitousKeyValueStoreAccountChange:
            // iCloud account changed
            break;
        default:
            break;
    }
    
    NSArray * keys = [userInfo objectForKey:NSUbiquitousKeyValueStoreChangedKeysKey];
    for (NSString * key in keys)
    {
//        NSLog(@"Value for key %@ changed", key);
    }
}

//- (void) applicationDidFinishLaunching: (UIApplication*) application
//{
//    ignoreUnused (application);
//    initialiseJuce_GUI();
//
//    if (auto* app = JUCEApplicationBase::createInstance())
//    {
//        if (! app->initialiseApp())
//            exit (app->shutdownApp());
//    }
//    else
//    {
//        jassertfalse; // you must supply an application object for an iOS app!
//    }
//}

- (void) applicationWillTerminate: (UIApplication*) application
{
    ignoreUnused (application);
    JUCEApplicationBase::appWillTerminateByForce();
}

- (void) applicationDidEnterBackground: (UIApplication*) application
{
    if (auto* app = JUCEApplicationBase::getInstance())
    {
       #if JUCE_EXECUTE_APP_SUSPEND_ON_BACKGROUND_TASK
        appSuspendTask = [application beginBackgroundTaskWithName:@"JUCE Suspend Task" expirationHandler:^{
            if (appSuspendTask != UIBackgroundTaskInvalid)
            {
                [application endBackgroundTask:appSuspendTask];
                appSuspendTask = UIBackgroundTaskInvalid;
            }
        }];

        MessageManager::callAsync ([app] { app->suspended(); });
       #else
        ignoreUnused (application);
        app->suspended();
       #endif
    }
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    
#if !IS_PRIMER && !SIMULATOR
    
    DBOAuthCompletion completion = ^(DBOAuthResult *authResult) {
       if (authResult != nil) {
         if ([authResult isSuccess]) {
           NSLog(@"\n\nSuccess! User is logged into Dropbox.\n\n");
         } else if ([authResult isCancel]) {
           NSLog(@"\n\nAuthorization flow was manually canceled by user!\n\n");
         } else if ([authResult isError]) {
           NSLog(@"\n\nError: %@\n\n", authResult);
         }
       }
     };
     BOOL canHandle = [DBClientsManager handleRedirectURL:url completion:completion];
     return canHandle;
#endif
}

- (void) applicationWillEnterForeground: (UIApplication*) application
{
    ignoreUnused (application);

    if (auto* app = JUCEApplicationBase::getInstance())
        app->resumed();
}

struct BadgeUpdateTrait
{
   #if JUCE_IOS_API_VERSION_CAN_BE_BUILT (16, 0)
    API_AVAILABLE (ios (16))
    static void newFn (UIApplication*)
    {
        [[UNUserNotificationCenter currentNotificationCenter] setBadgeCount: 0 withCompletionHandler: nil];
    }
   #endif

    static void oldFn (UIApplication* app)
    {
        JUCE_BEGIN_IGNORE_WARNINGS_GCC_LIKE ("-Wdeprecated-declarations")
        app.applicationIconBadgeNumber = 0;
        JUCE_END_IGNORE_WARNINGS_GCC_LIKE
    }
};

- (void) applicationDidBecomeActive: (UIApplication*) application
{
    ifelse_17_0<BadgeUpdateTrait> (application);
    isIOSAppActive = true;
}

- (void) applicationWillResignActive: (UIApplication*) application
{
    ignoreUnused (application);
    isIOSAppActive = false;

    for (int i = appBecomingInactiveCallbacks.size(); --i >= 0;)
        appBecomingInactiveCallbacks.getReference (i)->appBecomingInactive();
}

- (void) application: (UIApplication*) application handleEventsForBackgroundURLSession: (NSString*)identifier
   completionHandler: (void (^)(void))completionHandler
{
    ignoreUnused (application);
    URL::DownloadTask::juce_iosURLSessionNotify (nsStringToJuce (identifier));
    completionHandler();
}

- (void) applicationDidReceiveMemoryWarning: (UIApplication*) application
{
    ignoreUnused (application);

    if (auto* app = JUCEApplicationBase::getInstance())
        app->memoryWarningReceived();
}

- (void) setPushNotificationsDelegateToUse: (NSObject*) delegate
{
    _pushNotificationsDelegate = delegate;
}

#if JUCE_PUSH_NOTIFICATIONS
- (void) application: (UIApplication*) application didRegisterUserNotificationSettings: (UIUserNotificationSettings*) notificationSettings
{
    ignoreUnused (application);

    SEL selector = @selector (application:didRegisterUserNotificationSettings:);

    if (_pushNotificationsDelegate != nil && [_pushNotificationsDelegate respondsToSelector: selector])
    {
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [_pushNotificationsDelegate methodSignatureForSelector: selector]];
        [invocation setSelector: selector];
        [invocation setTarget: _pushNotificationsDelegate];
        [invocation setArgument: &application          atIndex:2];
        [invocation setArgument: &notificationSettings atIndex:3];

        [invocation invoke];
    }
}

- (void) application: (UIApplication*) application didRegisterForRemoteNotificationsWithDeviceToken: (NSData*) deviceToken
{
    ignoreUnused (application);

    SEL selector = @selector (application:didRegisterForRemoteNotificationsWithDeviceToken:);

    if (_pushNotificationsDelegate != nil && [_pushNotificationsDelegate respondsToSelector: selector])
    {
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [_pushNotificationsDelegate methodSignatureForSelector: selector]];
        [invocation setSelector: selector];
        [invocation setTarget: _pushNotificationsDelegate];
        [invocation setArgument: &application atIndex:2];
        [invocation setArgument: &deviceToken atIndex:3];

        [invocation invoke];
    }
}

- (void) application: (UIApplication*) application didFailToRegisterForRemoteNotificationsWithError: (NSError*) error
{
    ignoreUnused (application);

    SEL selector = @selector (application:didFailToRegisterForRemoteNotificationsWithError:);

    if (_pushNotificationsDelegate != nil && [_pushNotificationsDelegate respondsToSelector: selector])
    {
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [_pushNotificationsDelegate methodSignatureForSelector: selector]];
        [invocation setSelector: selector];
        [invocation setTarget: _pushNotificationsDelegate];
        [invocation setArgument: &application atIndex:2];
        [invocation setArgument: &error       atIndex:3];

        [invocation invoke];
    }
}

- (void) application: (UIApplication*) application didReceiveRemoteNotification: (NSDictionary*) userInfo
{
    ignoreUnused (application);

    SEL selector = @selector (application:didReceiveRemoteNotification:);

    if (_pushNotificationsDelegate != nil && [_pushNotificationsDelegate respondsToSelector: selector])
    {
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [_pushNotificationsDelegate methodSignatureForSelector: selector]];
        [invocation setSelector: selector];
        [invocation setTarget: _pushNotificationsDelegate];
        [invocation setArgument: &application atIndex:2];
        [invocation setArgument: &userInfo    atIndex:3];

        [invocation invoke];
    }
}

- (void) application: (UIApplication*) application didReceiveRemoteNotification: (NSDictionary*) userInfo
  fetchCompletionHandler: (void (^)(UIBackgroundFetchResult result)) completionHandler
{
    ignoreUnused (application);

    SEL selector = @selector (application:didReceiveRemoteNotification:fetchCompletionHandler:);

    if (_pushNotificationsDelegate != nil && [_pushNotificationsDelegate respondsToSelector: selector])
    {
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [_pushNotificationsDelegate methodSignatureForSelector: selector]];
        [invocation setSelector: selector];
        [invocation setTarget: _pushNotificationsDelegate];
        [invocation setArgument: &application       atIndex:2];
        [invocation setArgument: &userInfo          atIndex:3];
        [invocation setArgument: &completionHandler atIndex:4];

        [invocation invoke];
    }
}

- (void) application: (UIApplication*) application handleActionWithIdentifier: (NSString*) identifier
  forRemoteNotification: (NSDictionary*) userInfo withResponseInfo: (NSDictionary*) responseInfo
  completionHandler: (void(^)()) completionHandler
{
    ignoreUnused (application);

    SEL selector = @selector (application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:);

    if (_pushNotificationsDelegate != nil && [_pushNotificationsDelegate respondsToSelector: selector])
    {
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [_pushNotificationsDelegate methodSignatureForSelector: selector]];
        [invocation setSelector: selector];
        [invocation setTarget: _pushNotificationsDelegate];
        [invocation setArgument: &application       atIndex:2];
        [invocation setArgument: &identifier        atIndex:3];
        [invocation setArgument: &userInfo          atIndex:4];
        [invocation setArgument: &responseInfo      atIndex:5];
        [invocation setArgument: &completionHandler atIndex:6];

        [invocation invoke];
    }
}

- (void) userNotificationCenter: (UNUserNotificationCenter*) center
        willPresentNotification: (UNNotification*) notification
          withCompletionHandler: (void (^)(UNNotificationPresentationOptions options)) completionHandler
{
    ignoreUnused (center);

    SEL selector = @selector (userNotificationCenter:willPresentNotification:withCompletionHandler:);

    if (_pushNotificationsDelegate != nil && [_pushNotificationsDelegate respondsToSelector: selector])
    {
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [_pushNotificationsDelegate methodSignatureForSelector: selector]];
        [invocation setSelector: selector];
        [invocation setTarget: _pushNotificationsDelegate];
        [invocation setArgument: &center            atIndex:2];
        [invocation setArgument: &notification      atIndex:3];
        [invocation setArgument: &completionHandler atIndex:4];

        [invocation invoke];
    }
}

- (void) userNotificationCenter: (UNUserNotificationCenter*) center didReceiveNotificationResponse: (UNNotificationResponse*) response
         withCompletionHandler: (void(^)()) completionHandler
{
    ignoreUnused (center);

    SEL selector = @selector (userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);

    if (_pushNotificationsDelegate != nil && [_pushNotificationsDelegate respondsToSelector: selector])
    {
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: [_pushNotificationsDelegate methodSignatureForSelector: selector]];
        [invocation setSelector: selector];
        [invocation setTarget: _pushNotificationsDelegate];
        [invocation setArgument: &center            atIndex:2];
        [invocation setArgument: &response          atIndex:3];
        [invocation setArgument: &completionHandler atIndex:4];

        [invocation invoke];
    }
}
#endif
#endif

@end

namespace juce
{

int juce_iOSMain (int argc, const char* argv[], void* customDelegatePtr);
int juce_iOSMain (int argc, const char* argv[], void* customDelegatePtr)
{
    Class delegateClass = (customDelegatePtr != nullptr ? reinterpret_cast<Class> (customDelegatePtr) : [JuceAppStartupDelegate class]);

    return UIApplicationMain (argc, const_cast<char**> (argv), nil, NSStringFromClass (delegateClass));
}

//==============================================================================
void LookAndFeel::playAlertSound()
{
    // TODO
}

//==============================================================================

bool DragAndDropContainer::performExternalDragDropOfFiles (const StringArray&, bool, Component*, std::function<void()>)
{
    jassertfalse;    // no such thing on iOS!
    return false;
}

bool DragAndDropContainer::performExternalDragDropOfText (const String&, Component*, std::function<void()>)
{
    jassertfalse;    // no such thing on iOS!
    return false;
}

//==============================================================================
void Desktop::setScreenSaverEnabled (const bool isEnabled)
{
    if (! SystemStats::isRunningInAppExtensionSandbox())
        [[UIApplication sharedApplication] setIdleTimerDisabled: ! isEnabled];
}

bool Desktop::isScreenSaverEnabled()
{
    if (SystemStats::isRunningInAppExtensionSandbox())
        return true;

    return ! [[UIApplication sharedApplication] isIdleTimerDisabled];
}

//==============================================================================
Image detail::WindowingHelpers::createIconForFile (const File&)
{
    return {};
}

//==============================================================================
void SystemClipboard::copyTextToClipboard (const String& text)
{
    [[UIPasteboard generalPasteboard] setValue: juceStringToNS (text)
                             forPasteboardType: @"public.text"];
}

String SystemClipboard::getTextFromClipboard()
{
    return nsStringToJuce ([[UIPasteboard generalPasteboard] string]);
}

//==============================================================================
bool detail::MouseInputSourceList::addSource()
{
    addSource (sources.size(), MouseInputSource::InputSourceType::touch);
    return true;
}

bool detail::MouseInputSourceList::canUseTouch() const
{
    return true;
}

bool Desktop::canUseSemiTransparentWindows() noexcept
{
    return true;
}

bool Desktop::isDarkModeActive() const
{
    return [[[UIScreen mainScreen] traitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark;
}

class Desktop::NativeDarkModeChangeDetectorImpl
{
public:
    NativeDarkModeChangeDetectorImpl()
    {
        static DelegateClass delegateClass;

        delegate = [delegateClass.createInstance() init];
        object_setInstanceVariable (delegate, "owner", this);

        JUCE_BEGIN_IGNORE_WARNINGS_GCC_LIKE ("-Wundeclared-selector")
        [[NSNotificationCenter defaultCenter] addObserver: delegate
                                                 selector: @selector (darkModeChanged:)
                                                     name: UIViewComponentPeer::getDarkModeNotificationName()
                                                   object: nil];
        JUCE_END_IGNORE_WARNINGS_GCC_LIKE
    }

    ~NativeDarkModeChangeDetectorImpl()
    {
        object_setInstanceVariable (delegate, "owner", nullptr);
        [[NSNotificationCenter defaultCenter] removeObserver: delegate];
        [delegate release];
    }

    void darkModeChanged()
    {
        Desktop::getInstance().darkModeChanged();
    }

private:
    struct DelegateClass final : public ObjCClass<NSObject>
    {
        DelegateClass()  : ObjCClass<NSObject> ("JUCEDelegate_")
        {
            addIvar<NativeDarkModeChangeDetectorImpl*> ("owner");

            JUCE_BEGIN_IGNORE_WARNINGS_GCC_LIKE ("-Wundeclared-selector")
            addMethod (@selector (darkModeChanged:), darkModeChanged);
            JUCE_END_IGNORE_WARNINGS_GCC_LIKE

            registerClass();
        }

        static void darkModeChanged (id self, SEL, NSNotification*)
        {
            if (auto* owner = getIvar<NativeDarkModeChangeDetectorImpl*> (self, "owner"))
                owner->darkModeChanged();
        }
    };

    id delegate = nil;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (NativeDarkModeChangeDetectorImpl)
};

std::unique_ptr<Desktop::NativeDarkModeChangeDetectorImpl> Desktop::createNativeDarkModeChangeDetectorImpl()
{
    return std::make_unique<NativeDarkModeChangeDetectorImpl>();
}

Point<float> MouseInputSource::getCurrentRawMousePosition()
{
    return juce_lastMousePos;
}

void MouseInputSource::setRawMousePosition (Point<float>)
{
}

double Desktop::getDefaultMasterScale()
{
    return 1.0;
}

Desktop::DisplayOrientation Desktop::getCurrentOrientation() const
{
    UIInterfaceOrientation orientation = SystemStats::isRunningInAppExtensionSandbox() ? UIInterfaceOrientationPortrait
                                                                                       : getWindowOrientation();

    return Orientations::convertToJuce (orientation);
}

// The most straightforward way of retrieving the screen area available to an iOS app
// seems to be to create a new window (which will take up all available space) and to
// query its frame.
struct TemporaryWindow
{
    UIWindow* window = [[UIWindow alloc] init];
    ~TemporaryWindow() noexcept { [window release]; }
};

static Rectangle<int> getRecommendedWindowBounds()
{
    return convertToRectInt (TemporaryWindow().window.frame);
}

static BorderSize<int> getSafeAreaInsets (float masterScale)
{
    UIEdgeInsets safeInsets = TemporaryWindow().window.safeAreaInsets;
    return detail::WindowingHelpers::roundToInt (BorderSize<double> { safeInsets.top,
                                                                      safeInsets.left,
                                                                      safeInsets.bottom,
                                                                      safeInsets.right }.multipliedBy (1.0 / (double) masterScale));
}

void Displays::findDisplays (float masterScale)
{
    JUCE_BEGIN_IGNORE_WARNINGS_GCC_LIKE ("-Wundeclared-selector")
    static const auto keyboardShownSelector  = @selector (juceKeyboardShown:);
    static const auto keyboardHiddenSelector = @selector (juceKeyboardHidden:);
    JUCE_END_IGNORE_WARNINGS_GCC_LIKE

    class OnScreenKeyboardChangeDetectorImpl
    {
    public:
        OnScreenKeyboardChangeDetectorImpl()
        {
            static DelegateClass delegateClass;
            delegate.reset ([delegateClass.createInstance() init]);
            object_setInstanceVariable (delegate.get(), "owner", this);
            observers.emplace_back (delegate.get(), keyboardShownSelector,  UIKeyboardDidShowNotification, nil);
            observers.emplace_back (delegate.get(), keyboardHiddenSelector, UIKeyboardDidHideNotification, nil);
        }

        auto getInsets() const { return insets; }

    private:
        struct DelegateClass final : public ObjCClass<NSObject>
        {
            DelegateClass() : ObjCClass<NSObject> ("JUCEOnScreenKeyboardObserver_")
            {
                addIvar<OnScreenKeyboardChangeDetectorImpl*> ("owner");

                addMethod (keyboardShownSelector, [] (id self, SEL, NSNotification* notification)
                {
                    setKeyboardScreenBounds (self, [&]() -> BorderSize<double>
                    {
                        auto* info = [notification userInfo];

                        if (info == nullptr)
                            return {};

                        auto* value = static_cast<NSValue*> ([info objectForKey: UIKeyboardFrameEndUserInfoKey]);

                        if (value == nullptr)
                            return {};

                        auto* display = Desktop::getInstance().getDisplays().getPrimaryDisplay();

                        if (display == nullptr)
                            return {};

                        const auto rect = convertToRectInt ([value CGRectValue]);

                        BorderSize<double> result;

                        if (rect.getY() == display->totalArea.getY())
                            result.setTop (rect.getHeight());

                        if (rect.getBottom() == display->totalArea.getBottom())
                            result.setBottom (rect.getHeight());

                        return result;
                    }());
                });

                addMethod (keyboardHiddenSelector, [] (id self, SEL, NSNotification*)
                {
                    setKeyboardScreenBounds (self, {});
                });

                registerClass();
            }

        private:
            static void setKeyboardScreenBounds (id self, BorderSize<double> insets)
            {
                if (std::exchange (getIvar<OnScreenKeyboardChangeDetectorImpl*> (self, "owner")->insets, insets) != insets)
                    Desktop::getInstance().displays->refresh();
            }
        };

        BorderSize<double> insets;
        NSUniquePtr<NSObject> delegate;
        std::vector<ScopedNotificationCenterObserver> observers;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (OnScreenKeyboardChangeDetectorImpl)
    };

    JUCE_AUTORELEASEPOOL
    {
        static OnScreenKeyboardChangeDetectorImpl keyboardChangeDetector;
        
        UIScreen* s = [UIScreen mainScreen];

        Display d;
        d.totalArea = convertToRectInt ([s bounds]) / masterScale;
        d.userArea = getRecommendedWindowBounds() / masterScale;
        d.safeAreaInsets = getSafeAreaInsets (masterScale);
        const auto scaledInsets = keyboardChangeDetector.getInsets().multipliedBy (1.0 / (double) masterScale);
        d.keyboardInsets = detail::WindowingHelpers::roundToInt (scaledInsets);
        d.isMain = true;
        d.scale = masterScale * s.scale;
        d.dpi = 160 * d.scale;

        displays.add (d);
    }
}

} // namespace juce
