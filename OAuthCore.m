//
//  OAuthCore.m
//
//  Created by Loren Brichter on 6/9/10.
//  Copyright 2010 Loren Brichter. All rights reserved.
//

#import "OAuthCore.h"
#import "OAuth+Additions.h"
#import "NSData+Base64.h"
#import <CommonCrypto/CommonHMAC.h>

static NSInteger SortParameter(NSString *key1, NSString *key2, void *context) {
	NSComparisonResult r = [key1 compare:key2];
	if(r == NSOrderedSame) { // compare by value in this case
		NSDictionary *dict = (NSDictionary *)context;
		NSString *value1 = [dict objectForKey:key1];
		NSString *value2 = [dict objectForKey:key2];
		return [value1 compare:value2];
	}
	return r;
}

static NSData *HMAC_SHA1(NSString *data, NSString *key) {
	unsigned char buf[CC_SHA1_DIGEST_LENGTH];
	CCHmac(kCCHmacAlgSHA1, [key UTF8String], [key length], [data UTF8String], [data length], buf);
	return [NSData dataWithBytes:buf length:CC_SHA1_DIGEST_LENGTH];
}

static int DefaultPortForScheme(NSString *scheme) {
    if ([@"http" isEqualToString: scheme] == YES) {
        return 80;
    }
    else if ([@"https" isEqualToString: scheme] == YES) {
        return 443;
    }
    else {
        return 0;
    }
}

static NSString * URLPathWithTrailingSlash(NSURL *url) {
    NSString * path = [url absoluteString];
    NSArray * components = [path componentsSeparatedByString: @"?"];
    path = (NSString *)[components objectAtIndex: 0];
    path = [path substringFromIndex: [path rangeOfString: [url path]].location];
    return path;
}

NSString *OAuthorizationHeader(NSURL *url, NSString *method, NSData *body, NSString *_oAuthConsumerKey, NSString *_oAuthConsumerSecret, NSString *_oAuthToken, NSString *_oAuthTokenSecret)
{
	NSString *_oAuthNonce = [NSString ab_GUID];
	NSString *_oAuthTimestamp = [NSString stringWithFormat:@"%d", (int)[[NSDate date] timeIntervalSince1970]];
    NSString *_oAuthSignatureMethod;
    if([method isEqualToString:@"PUT"]){
        _oAuthSignatureMethod = @"PLAINTEXT";
    }else{
        _oAuthSignatureMethod = @"PLAINTEXT";
    }
    NSString *_oAuthVersion = @"1.0";
	
	NSMutableDictionary *oAuthAuthorizationParameters = [NSMutableDictionary dictionary];
	[oAuthAuthorizationParameters setObject:_oAuthNonce forKey:@"oauth_nonce"];
	[oAuthAuthorizationParameters setObject:_oAuthTimestamp forKey:@"oauth_timestamp"];
	[oAuthAuthorizationParameters setObject:_oAuthSignatureMethod forKey:@"oauth_signature_method"];
	[oAuthAuthorizationParameters setObject:_oAuthVersion forKey:@"oauth_version"];
	[oAuthAuthorizationParameters setObject:_oAuthConsumerKey forKey:@"oauth_consumer_key"];
	if(_oAuthToken)
		[oAuthAuthorizationParameters setObject:_oAuthToken forKey:@"oauth_token"];
	
	// get query and body parameters
	NSDictionary *additionalQueryParameters = [NSURL ab_parseURLQueryString:[url query]];
	NSDictionary *additionalBodyParameters = nil;
	if(body) {
		NSString *string = [[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] autorelease];
		if(string) {
			additionalBodyParameters = [NSURL ab_parseURLQueryString:string];
		}
	}
	
	// combine all parameters
	NSMutableDictionary *parameters = [[oAuthAuthorizationParameters mutableCopy] autorelease];
	if(additionalQueryParameters) [parameters addEntriesFromDictionary:additionalQueryParameters];
	if(additionalBodyParameters) [parameters addEntriesFromDictionary:additionalBodyParameters];
	
	// -> UTF-8 -> RFC3986
	NSMutableDictionary *encodedParameters = [NSMutableDictionary dictionary];
	for(NSString *key in parameters) {
		NSString *value = [parameters objectForKey:key];
		[encodedParameters setObject:[value ab_RFC3986EncodedString] forKey:[key ab_RFC3986EncodedString]];
	}
	
	NSArray *sortedKeys = [[encodedParameters allKeys] sortedArrayUsingFunction:SortParameter context:encodedParameters];
	
	NSMutableArray *parameterArray = [NSMutableArray array];
	for(NSString *key in sortedKeys) {
		[parameterArray addObject:[NSString stringWithFormat:@"%@=%@", key, [encodedParameters objectForKey:key]]];
	}
	
    // make sure we handle the port correctly - if the port is the default for the scheme, we should use it, otherwise don't
	NSString *normalizedURLString = nil;
    if ( [[url port] intValue] == DefaultPortForScheme([url scheme]) ) {
        normalizedURLString = [NSString stringWithFormat:@"%@://%@%@", [url scheme], [url host], URLPathWithTrailingSlash(url)];
    }
    else {
        normalizedURLString = [NSString stringWithFormat:@"%@://%@:%@%@", [url scheme], [url host], [url port], URLPathWithTrailingSlash(url)];
    }
    
    NSMutableDictionary *authorizationHeaderDictionary = [[oAuthAuthorizationParameters mutableCopy] autorelease];
	[authorizationHeaderDictionary setObject:@"th1nkt1v&fAAZrJa3raL7zXHArDBDMRA4VPLDDwru" forKey:@"oauth_signature"];
    
    NSMutableArray *authorizationHeaderItems = [NSMutableArray array];
	for(NSString *key in authorizationHeaderDictionary) {
		NSString *value = [authorizationHeaderDictionary objectForKey:key];
		[authorizationHeaderItems addObject:[NSString stringWithFormat:@"%@=\"%@\"",
											 [key ab_RFC3986EncodedString],
											 [value ab_RFC3986EncodedString]]];
	}
	
	NSString *authorizationHeaderString = [authorizationHeaderItems componentsJoinedByString:@", "];
	authorizationHeaderString = [NSString stringWithFormat:@"OAuth %@", authorizationHeaderString];
	
	return authorizationHeaderString;
}
