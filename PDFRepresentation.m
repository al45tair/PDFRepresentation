/*
 * PDFRepresentation method for NSImage
 *
 */

#import <Cocoa/Cocoa.h>

#import "PDFRepresentation.h"

/* First we declare a new type of NSGraphicsContext that uses a Quartz
   PDF context to render directly into an NSMutableData object. */
@interface PDFGraphicsContext : NSGraphicsContext
{
  CGContextRef  context;
  NSMutableData *data;
  CGRect        defaultFrame;
  
  NSImageInterpolation imageInterpolation;
  NSPoint	       patternPhase;
  BOOL		       shouldAntialias;
}

- (id) initWithFrame:(NSRect)frame info:(NSDictionary *)info;

- (NSData *) PDFRepresentation;

- (void) beginPage;
- (void) beginPageWithFrame:(NSRect)frame;
- (void) endPage;

@end

@implementation PDFGraphicsContext

static size_t
NSMutableDataConsumerPutBytes (void *info, const void *buffer, size_t count)
{
    NSMutableData *data = (NSMutableData *) info;
    unsigned old_len = [data length];

    [data appendBytes:buffer length:count];

    return [data length] - old_len;
}

- (id)initWithFrame:(NSRect)frame info:(NSDictionary *)info
{
    CGDataConsumerCallbacks callbacks = { NSMutableDataConsumerPutBytes, NULL };
    CGDataConsumerRef       consumer;

    if ((self = [super init])) {
        CGRect mediaBox;
        mediaBox.origin.x = frame.origin.x;
        mediaBox.origin.y = frame.origin.y;
        mediaBox.size.width = frame.size.width;
        mediaBox.size.height = frame.size.height;

        imageInterpolation = NSImageInterpolationDefault;
        patternPhase = NSMakePoint (0.0, 0.0);
        
        data = [[NSMutableData alloc] init];
        consumer = CGDataConsumerCreate (data, &callbacks);
        if (!consumer) {
            [self release];
            return nil;
        }
        defaultFrame = mediaBox;
        context = CGPDFContextCreate (consumer, &mediaBox,
				      (CFDictionaryRef) info);
        CGDataConsumerRelease (consumer);
        if (!context) {
            [self release];
            return nil;
        }
    }

    return self;
}

- (void)dealloc
{
    CGContextRelease (context);
    [data release];
    [super dealloc];
}

- (void) beginPage
{
    CGContextBeginPage (context, &defaultFrame);
}

- (void) beginPageWithFrame:(NSRect)frame
{
    CGRect mediaBox;
    mediaBox.origin.x = frame.origin.x;
    mediaBox.origin.y = frame.origin.y;
    mediaBox.size.width = frame.size.width;
    mediaBox.size.height = frame.size.height;

    CGContextBeginPage (context, &mediaBox);
}

- (void) endPage
{
    CGContextEndPage (context);
}

- (void) flushGraphics
{
    CGContextFlush (context);
}

- (NSData *) PDFRepresentation
{
    [self flushGraphics];
    return data;
}

- (void *)graphicsPort
{
    return context;
}

- (void)saveGraphicsState
{
    CGContextSaveGState (context);
}

- (void)restoreGraphicsState
{
    CGContextRestoreGState (context);
}

- (BOOL)isDrawingToScreen
{
    return NO;
}

- (NSDictionary *)attributes
{
    return nil;
}

- (NSImageInterpolation)imageInterpolation
{
    return imageInterpolation;
}

- (void)setImageInterpolation:(NSImageInterpolation)newInterpolation
{
    imageInterpolation = newInterpolation;
    switch (newInterpolation)
    {
        case NSImageInterpolationNone:
            CGContextSetInterpolationQuality (context, kCGInterpolationNone);
            break;
        case NSImageInterpolationLow:
            CGContextSetInterpolationQuality (context, kCGInterpolationLow);
            break;
        case NSImageInterpolationHigh:
            CGContextSetInterpolationQuality (context, kCGInterpolationHigh);
            break;
        case NSImageInterpolationDefault:
        default:
            CGContextSetInterpolationQuality (context, kCGInterpolationDefault);
            break;
    }
}

- (NSPoint)patternPhase
{
    return patternPhase;
}

- (void)setPatternPhase:(NSPoint)phase
{
    CGSize cgPhase;
    
    patternPhase = phase;
    cgPhase.width = phase.x;
    cgPhase.height = phase.y;
    CGContextSetPatternPhase (context, cgPhase);
}

- (BOOL)shouldAntialias
{
    return shouldAntialias;
}

- (void)setShouldAntialias:(BOOL)antialias
{
    shouldAntialias = antialias;
    CGContextSetShouldAntialias (context, antialias);
}

/* -focusStack and -setFocusStack are intentionally not implemented */

@end

/* Then we use the PDFGraphicsContext to render the image into an NSData,
   which we return to the caller. */
@implementation NSImage (PDFRepresentation)

-(NSData *) PDFRepresentation
{
    NSData *pdfData;
    NSRect frame = NSMakeRect (0.0, 0.0, [self size].width, [self size].height);
    PDFGraphicsContext *pdfContext = [[PDFGraphicsContext alloc] initWithFrame:frame info:nil];
    NSGraphicsContext *savedContext = [NSGraphicsContext currentContext];

    [NSGraphicsContext setCurrentContext:pdfContext];
    [pdfContext beginPage];
    [self drawInRect:frame fromRect:frame
	  operation:NSCompositeCopy
	  fraction:1.0];
    [pdfContext endPage];
    [NSGraphicsContext setCurrentContext:savedContext];
    pdfData = [[pdfContext PDFRepresentation] retain];
    [pdfContext release];

    return [pdfData autorelease];
}

@end
