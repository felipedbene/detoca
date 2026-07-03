//
//  PlayQueueItem.h
//  DeToca
//
//  One entry in the play queue: a display title and a URL string. Deliberately
//  gopher-agnostic (the player never learns gopher exists). Pure Foundation.
//

#import <Foundation/Foundation.h>

@interface PlayQueueItem : NSObject {
    NSString *_title;
    NSString *_urlString;
}

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *urlString;

+ (id)itemWithTitle:(NSString *)title urlString:(NSString *)urlString;

@end
