//
//  LMReverseGeocoder.m
//  LMLibrary
//
//  Created by LMinh on 31/05/2014.
//  Copyright (c) Năm 2014 LMinh. All rights reserved.
//

#import "LMGeocoder.h"

#define kGoogleAPIReverseGeocodingURL(lat, lng) [NSString stringWithFormat:@"http://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true", lat, lng];
#define kGoogleAPIGeocodingURL(address)         [NSString stringWithFormat:@"http://maps.googleapis.com/maps/api/geocode/json?address=%@&sensor=true", address];
#define kTimeoutInterval 60

@interface LMGeocoder ()

@property (assign, nonatomic) BOOL isReverseGeocoding;
@property (assign, nonatomic) LMGeocoderService currentService;

@property (assign, nonatomic) CLLocationCoordinate2D requestedCoordinate;
@property (strong, nonatomic) NSString *requestedAddress;
@property (strong, nonatomic) LMGeocodeCallback completionHandler;
@property (strong, nonatomic) CLGeocoder *appleGeocoder;

@end

@implementation LMGeocoder

#pragma mark - INIT

+ (LMGeocoder *)sharedInstance
{
    static LMGeocoder *instance = nil;
    if (instance == nil) {
        instance = [[LMGeocoder alloc] init];
    }
    return instance;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        self.appleGeocoder = [[CLGeocoder alloc] init];
    }
    return self;
}


#pragma mark - GEOCODING

- (void)geocodeAddressString:(NSString *)addressString
                     service:(LMGeocoderService)service
           completionHandler:(LMGeocodeCallback)handler
{
    self.isReverseGeocoding = NO;
    self.requestedAddress = addressString;
    self.completionHandler = handler;
    self.currentService = service;
    
    if (self.requestedAddress == nil || self.requestedAddress.length == 0)
    {
        // Invalid address string, so return
        NSError *error = [NSError errorWithDomain:@"LMGeocoderError"
                                             code:kLMGeocoderErrorInvalidAddressString
                                         userInfo:nil];
        
        if (self.completionHandler) {
            self.completionHandler(nil, error);
        }
    }
    else
    {
        if (self.currentService == kLMGeocoderGoogleService)
        {
            // Build url string using address query
            NSString *urlString = kGoogleAPIGeocodingURL(self.requestedAddress);
            
            // Build connection from this url string
            [self buildConnectionFromURLString:urlString];
        }
        else
        {
            [self.appleGeocoder geocodeAddressString:self.requestedAddress
                                   completionHandler:^(NSArray *placemarks, NSError *error) {
                                       
                                       if (!error && placemarks) {
                                           [self parseGeocodingResultData:placemarks];
                                       }
                                       else {
                                           if (self.completionHandler) {
                                               self.completionHandler(nil, error);
                                           }
                                       }
                                   }];
        }
    }
}


#pragma mark - REVERSE GEOCODING

- (void)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
                         service:(LMGeocoderService)service
               completionHandler:(LMGeocodeCallback)handler
{
    self.isReverseGeocoding = YES;
    self.requestedCoordinate = coordinate;
    self.completionHandler = handler;
    self.currentService = service;
    
    if (!CLLocationCoordinate2DIsValid(self.requestedCoordinate))
    {
        // Invalid location coordinate, so return
        NSError *error = [NSError errorWithDomain:@"LMGeocoderError"
                                             code:kLMGeocoderErrorInvalidCoordinate
                                         userInfo:nil];
        
        if (self.completionHandler) {
            self.completionHandler(nil, error);
        }
    }
    else
    {
        if (self.currentService == kLMGeocoderGoogleService)
        {
            // Build url string using coordinate
            NSString *urlString = kGoogleAPIReverseGeocodingURL(self.requestedCoordinate.latitude, self.requestedCoordinate.longitude);
            
            // Build connection from this url string
            [self buildConnectionFromURLString:urlString];
        }
        else
        {
            CLLocation *location = [[CLLocation alloc] initWithLatitude:self.requestedCoordinate.latitude
                                                              longitude:self.requestedCoordinate.longitude];
            [self.appleGeocoder reverseGeocodeLocation:location
                                     completionHandler:^(NSArray *placemarks, NSError *error) {
                                         
                                         if (!error && placemarks) {
                                             [self parseGeocodingResultData:placemarks];
                                         }
                                         else {
                                             if (self.completionHandler) {
                                                 self.completionHandler(nil, error);
                                             }
                                         }
                                     }];
        }
    }
}


#pragma mark - CONNECTION STUFF

- (void)buildConnectionFromURLString:(NSString *)urlString
{
    NSURL *requestURL = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
   
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:requestURL];
    [request setTimeoutInterval:kTimeoutInterval];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *reponse, NSData *data, NSError *error) {
                               
                               if (!error)
                               {
                                   NSError *err = nil;
                                   id resultDict = [NSJSONSerialization JSONObjectWithData:data
                                                                                   options:NSJSONReadingAllowFragments
                                                                                     error:&err];
                                   
                                   if (!err && resultDict) {
                                       // Parse JSON data to LMAddress
                                       [self parseGeocodingResultData:resultDict];
                                   }
                                   else {
                                       if (self.completionHandler) {
                                           self.completionHandler(nil, error);
                                       }
                                   }
                               }
                               else
                               {
                                   if (self.completionHandler) {
                                       self.completionHandler(nil, error);
                                   }
                               }
                           }];
}


#pragma mark - PARSE RESULT DATA

- (void)parseGeocodingResultData:(id)resultData
{
    NSArray *addresses;
    switch (self.currentService) {
        case kLMGeocoderGoogleService:
            addresses = [self parseGoogleGeocodingResultData:resultData];
            break;
        case kLMGeocoderAppleService:
            addresses = [self parseAppleGeocodingResultData:resultData];
            break;
        default:
            break;
    }
    
    if ([addresses count] > 0)
    {
        if (self.completionHandler) {
            self.completionHandler(addresses, nil);
        }
    }
    else
    {
        NSError *error = [NSError errorWithDomain:@"LMGeocoderError"
                                             code:kLMGeocoderErrorInternal
                                         userInfo:nil];
        
        if (self.completionHandler) {
            self.completionHandler(nil, error);
        }
    }
}

- (NSArray *) parseAppleGeocodingResultData:(id)resultData
{
    LMAddress *resultAddress = [[LMAddress alloc] initWithLocationData:resultData
                                                        forServiceType:self.currentService];
    if (resultAddress.isValid) {
        return @[resultAddress];
    }
    
    return @[];
}

- (NSArray *) parseGoogleGeocodingResultData:(id)resultData
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSDictionary *resultDict = (NSDictionary *)resultData;
    NSString *status = [resultDict valueForKey:@"status"];
    
    if ([status isEqualToString:@"OK"])
    {
        for (NSDictionary *locationDict in [resultData objectForKey:@"results"]) {
            LMAddress *resultAddress = [[LMAddress alloc] initWithGoogleLocationData:locationDict];
            if (resultAddress.isValid) {
                [result addObject:resultAddress];
            }
        }
        
    }
    
    return [NSArray arrayWithArray:result];
}

@end
