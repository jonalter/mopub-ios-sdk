//
//  MPBannerAdInfo.h
//  MoPub
//
//  Copyright (c) 2013 MoPub. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPBannerAdInfo : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *ID;

+ (NSArray *)bannerAds;
+ (MPBannerAdInfo *)infoWithTitle:(NSString *)title ID:(NSString *)ID;

@end