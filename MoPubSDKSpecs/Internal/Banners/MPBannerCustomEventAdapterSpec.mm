#import "MPBannerCustomEventAdapter.h"
#import "MPAdConfigurationFactory.h"
#import "FakeBannerCustomEvent.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(MPBannerCustomEventAdapterSpec)

describe(@"MPBannerCustomEventAdapter", ^{
    __block MPBannerCustomEventAdapter *adapter;
    __block id<CedarDouble, MPAdapterDelegate> delegate;
    __block MPAdConfiguration *configuration;
    __block FakeBannerCustomEvent *event;

    beforeEach(^{
        delegate = nice_fake_for(@protocol(MPAdapterDelegate));
        adapter = [[[MPBannerCustomEventAdapter alloc] initWithAdapterDelegate:delegate] autorelease];
        configuration = [MPAdConfigurationFactory defaultBannerConfigurationWithCustomEventClassName:@"FakeBannerCustomEvent"];
        event = [[[FakeBannerCustomEvent alloc] init] autorelease];
        fakeProvider.FakeBannerCustomEvent = event;
    });

    context(@"when asked to get an ad for a configuration", ^{
        context(@"when the requested custom event class exists", ^{
            beforeEach(^{
                configuration.customEventClassData = @{@"Zoology":@"Is for zoologists"};
                [adapter _getAdWithConfiguration:configuration containerSize:CGSizeMake(10,32)];
            });

            it(@"should create a new instance of the class and request the interstitial", ^{
                event.delegate should equal(adapter);
                event.size should equal(CGSizeMake(10,32));
                event.customEventInfo should equal(configuration.customEventClassData);
            });
        });

        context(@"when the requested custom event class does not exist", ^{
            beforeEach(^{
                fakeProvider.FakeBannerCustomEvent = nil;
                configuration = [MPAdConfigurationFactory defaultInterstitialConfigurationWithCustomEventClassName:@"NonExistentCustomEvent"];
                [adapter _getAdWithConfiguration:configuration containerSize:CGSizeZero];
            });

            it(@"should not create an instance, and should tell its delegate that it failed to load", ^{
                delegate should have_received(@selector(adapter:didFailToLoadAdWithError:)).with(adapter).and_with(nil);
            });
        });
    });

    describe(@"regression test: make sure the event is not dealloced immediately after unregisterDelegate is called", ^{
        //  This was an issue where the destinationDisplayAgent would try to set some state after causing the modal to dismiss.
        //  In cases where there was an ad waiting in the wings, the onscreen ad would be deallocated immediately after the modal is dismissed causing the destinationdisplayagent to explode.

        it(@"should not blow up", ^{
            FakeBannerCustomEvent *event = [[FakeBannerCustomEvent alloc] initWithFrame:CGRectZero];
            fakeProvider.fakeBannerCustomEvent = event;

            [adapter _getAdWithConfiguration:configuration containerSize:CGSizeZero];
            [event release]; //the adapter has him now

            [adapter unregisterDelegate];

            //previously the event would be deallocarted at this point.
            //not any more!
            event should be_instance_of([FakeBannerCustomEvent class]);
            event.view should_not be_nil;
        });
    });


    context(@"with a valid custom event", ^{
        beforeEach(^{
            [adapter _getAdWithConfiguration:configuration containerSize:CGSizeMake(20, 24)];
        });

        it(@"should make the configuration available", ^{
            adapter.configuration should equal(configuration);
        });

        context(@"when informed of an orientation change", ^{
            it(@"should forward the message to its custom event", ^{
                [adapter rotateToOrientation:UIInterfaceOrientationLandscapeLeft];
                event.orientation should equal(UIInterfaceOrientationLandscapeLeft);
            });
        });

        context(@"when the custom event claims to have loaded", ^{
            beforeEach(^{
                [delegate reset_sent_messages];
            });

            context(@"and passes in a non-nil ad", ^{
                it(@"should tell the delegate that the adapter finished loading, and pass on the view", ^{
                    UIView *view = [[[UIView alloc] init] autorelease];
                    [adapter bannerCustomEvent:event didLoadAd:view];
                    delegate should have_received(@selector(adapter:didFinishLoadingAd:)).with(adapter).and_with(view);
                });
            });

            context(@"and passes in a nil ad", ^{
                it(@"should tell the delegate that the adapter *failed* to load", ^{
                    [adapter bannerCustomEvent:event didLoadAd:nil];
                    delegate should have_received(@selector(adapter:didFailToLoadAdWithError:)).with(adapter).and_with(nil);
                });
            });
        });


        context(@"when told that its content has been displayed on-screen", ^{
            context(@"if the custom event has enabled automatic metrics tracking", ^{
                it(@"should track an impression (only once) and forward the message to its custom event", ^{
                    event.enableAutomaticMetricsTracking = YES;
                    [adapter didDisplayAd];
                    fakeProvider.sharedFakeMPAnalyticsTracker.trackedImpressionConfigurations should contain(configuration);
                    event.didDisplay should equal(YES);

                    [adapter didDisplayAd];
                    fakeProvider.sharedFakeMPAnalyticsTracker.trackedImpressionConfigurations.count should equal(1);
                });
            });

            context(@"if the custom event has disabled automatic metrics tracking", ^{
                it(@"should forward the message to its custom event but *not* track an impression", ^{
                    event.enableAutomaticMetricsTracking = NO;
                    [adapter didDisplayAd];
                    fakeProvider.sharedFakeMPAnalyticsTracker.trackedImpressionConfigurations should be_empty;
                    event.didDisplay should equal(YES);
                });
            });
        });

        context(@"when the custom event is beginning a user action", ^{
            context(@"if the custom event has enabled automatic metrics tracking", ^{
                it(@"should track a click (only once)", ^{
                    event.enableAutomaticMetricsTracking = YES;
                    [event simulateUserTap];
                    fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should contain(configuration);

                    [event simulateUserTap];
                    fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations.count should equal(1);
                });
            });

            context(@"if the custom event has disabled automatic metrics tracking", ^{
                it(@"should *not* track a click", ^{
                    event.enableAutomaticMetricsTracking = NO;
                    [event simulateUserTap];
                    fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should be_empty;
                });
            });
        });

        describe(@"the adapter timeout", ^{
            context(@"when the custom event successfully loads", ^{
                it(@"should no longer trigger a timeout", ^{
                    [event simulateLoadingAd];
                    [delegate reset_sent_messages];
                    [fakeProvider advanceMPTimers:BANNER_TIMEOUT_INTERVAL];
                    delegate.sent_messages should be_empty;
                });
            });

            context(@"when the custom event fails to load", ^{
                it(@"should invalidate the timer", ^{
                    [event simulateLoadingAd];
                    [delegate reset_sent_messages];
                    [fakeProvider advanceMPTimers:BANNER_TIMEOUT_INTERVAL];
                    delegate.sent_messages should be_empty;
                });
            });
        });

        context(@"when told to unregister", ^{
            it(@"should inform its custom event instance that it is going away", ^{
                [adapter unregisterDelegate];
                event.didUnload should equal(YES);
            });
        });
    });
});

SPEC_END