//
//  KVNProgress.m
//  KVNProgress
//
//  Created by Kevin Hirsch on 24/05/14.
//  Copyright (c) 2014 Kevin Hirsch. All rights reserved.
//

@import QuartzCore;
@import GLKit;

#import "KVNProgress.h"

#import "UIImage+ImageEffects.h"
#import "UIImage+Empty.h"

static CGFloat const KVNFadeAnimationDuration = 0.3f;
static CGFloat const KVNLayoutAnimationDuration = 0.3f;
static CGFloat const KVNTextUpdateAnimationDuration = 0.5f;
static CGFloat const KVNInfiniteLoopAnimationDuration = 1.0f;
static CGFloat const KVNProgressAnimationDuration = 0.25f;
static CGFloat const KVNProgressIndeterminate = CGFLOAT_MAX;
static CGFloat const KNVCircleProgressViewToStatusLabelVerticalSpaceConstraintConstant = 20.0f;

@interface KVNProgress ()

@property (nonatomic, getter = isIndeterminate) BOOL indeterminate;
@property (nonatomic) CGFloat progress;
@property (nonatomic) KVNProgressBackgroundType backgroundType;
@property (nonatomic) NSString *status;

// UI
@property (nonatomic, weak) IBOutlet UIView *contentView;
@property (nonatomic, weak) IBOutlet UIView *circleProgressView;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UIImageView *backgroundImageView;

@property (nonatomic, strong) CAShapeLayer *circleProgressLineLayer;
@property (nonatomic, strong) CAShapeLayer *circleBackgroundLineLayer;

// Constraints
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *circleProgressViewWidthConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *circleProgressViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *circleProgressViewToStatusLabelVerticalSpaceConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *statusLabelHeightConstraint;

@end

@implementation KVNProgress

#pragma mark - Shared view

+ (KVNProgress *)sharedView
{
	static KVNProgress *sharedView = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		UINib *nib = [UINib nibWithNibName:@"KVNProgressView"
									bundle:nil];
		NSArray *nibViews = [nib instantiateWithOwner:self
											  options:kNilOptions];
		
		sharedView = nibViews[0];
	});
	
	return sharedView;
}

#pragma mark - Life cycle

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
		// Appearance
		_backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
		_backgroundTintColor = [UIColor whiteColor];
		
		_circleStrokeForegroundColor = [UIColor lightGrayColor];
		_circleStrokeBackgroundColor = [_circleStrokeForegroundColor colorWithAlphaComponent:0.2f];
		_circleFillBackgroundColor = [UIColor clearColor];
		
		_statusColor = [UIColor grayColor];
		_statusFont = [UIFont systemFontOfSize:17.0f];
		
		_circleSize = 90.0f;
		_lineWidth = 2.0f;
    }
	
    return self;
}

#pragma mark - UI

- (void)setupUI
{
	[self setupCircleProgressView];
	[self setupStatus:self.status];
	[self setupBackground];
}

- (void)setupCircleProgressView
{
	// Constraints
	self.circleProgressViewWidthConstraint.constant = self.circleSize;
	self.circleProgressViewHeightConstraint.constant = self.circleSize;
	
	[self layoutIfNeeded];
	
	// Circle shape
	self.circleProgressView.layer.cornerRadius = (_circleSize / 2.0f);
	self.circleProgressView.layer.masksToBounds = YES;
	self.circleProgressView.backgroundColor = [UIColor clearColor];
	
	// Remove all previous added layers
	for (CALayer *subLayer in [self.circleProgressView.layer.sublayers copy]) {
		/* Technical :
		 we use a copy of self.circleProgressView.layer.sublayers because this array will
		 change when we remove its sublayers
		 */
		[subLayer removeFromSuperlayer];
	}
	
	if ([self isIndeterminate]) {
		[self setupInfiniteCircle];
	} else {
		[self setupProgressCircle];
	}
}

- (void)setupInfiniteCircle
{
	CGFloat radius = (self.circleSize / 2.0f);
	CGPoint center = CGPointMake(radius, radius);
	
	UIBezierPath *circlePath = [UIBezierPath bezierPathWithArcCenter:center
															  radius:(radius - self.lineWidth)
														  startAngle:GLKMathDegreesToRadians(-45.0f)
															endAngle:GLKMathDegreesToRadians(275.0f)
														   clockwise:YES];
	
	self.circleProgressLineLayer = [CAShapeLayer layer];
	self.circleProgressLineLayer.path = circlePath.CGPath;
	self.circleProgressLineLayer.strokeColor = self.circleStrokeForegroundColor.CGColor;
	self.circleProgressLineLayer.fillColor = self.circleFillBackgroundColor.CGColor;
	self.circleProgressLineLayer.lineWidth = self.lineWidth;
	
	[self.circleProgressView.layer addSublayer:self.circleProgressLineLayer];
	
	[self.circleProgressLineLayer removeAllAnimations];
	[self.circleProgressView.layer removeAllAnimations];
	[self animateCircleWithInfiniteLoop];
}

- (void)setupProgressCircle
{
	CGFloat radius = (self.circleSize / 2.0f);
	CGPoint center = CGPointMake(radius, radius);
	
	UIBezierPath *circlePath = [UIBezierPath bezierPathWithArcCenter:center
															  radius:(radius - self.lineWidth)
														  startAngle:GLKMathDegreesToRadians(-90.0f)
															endAngle:GLKMathDegreesToRadians(275.0f)
														   clockwise:YES];
	
	self.circleProgressLineLayer = [CAShapeLayer layer];
	self.circleProgressLineLayer.path = circlePath.CGPath;
	self.circleProgressLineLayer.strokeColor = self.circleStrokeForegroundColor.CGColor;
	self.circleProgressLineLayer.fillColor = [UIColor clearColor].CGColor;
	self.circleProgressLineLayer.lineWidth = self.lineWidth;
	
	self.circleBackgroundLineLayer = [CAShapeLayer layer];
	self.circleBackgroundLineLayer.path = circlePath.CGPath;
	self.circleBackgroundLineLayer.strokeColor = self.circleStrokeBackgroundColor.CGColor;
	self.circleBackgroundLineLayer.fillColor = self.circleFillBackgroundColor.CGColor;
	self.circleBackgroundLineLayer.lineWidth = self.lineWidth;
	
	[self.circleProgressView.layer addSublayer:self.circleBackgroundLineLayer];
	[self.circleProgressView.layer addSublayer:self.circleProgressLineLayer];
	
	[self.circleProgressLineLayer removeAllAnimations];
	[self.circleProgressView.layer removeAllAnimations];
	
	[self updateProgress:self.progress
				animated:NO];
}

- (void)setupStatus:(NSString *)status
{
	self.status = status;
	
	BOOL showStatus = (self.status.length > 0);
	
	CATransition *animation = [CATransition animation];
	animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	animation.type = kCATransitionFade;
	animation.duration = KVNTextUpdateAnimationDuration;
	[self.statusLabel.layer addAnimation:animation forKey:@"kCATransitionFade"];
	
	self.statusLabel.text = self.status;
	self.statusLabel.textColor = self.statusColor;
	self.statusLabel.font = self.statusFont;
	self.statusLabel.hidden = !showStatus;
	
	self.circleProgressViewToStatusLabelVerticalSpaceConstraint.constant = (showStatus) ? KNVCircleProgressViewToStatusLabelVerticalSpaceConstraintConstant : 0.0f;
	
	CGSize maximumLabelSize = CGSizeMake(CGRectGetWidth(self.statusLabel.bounds), CGFLOAT_MAX);
	CGSize statusLabelSize = [self.statusLabel sizeThatFits:maximumLabelSize];
	self.statusLabelHeightConstraint.constant = statusLabelSize.height;
	
	[self layoutIfNeeded];
}

- (void)setupBackground
{
	if ([self isVisible]) {
		return; // No reload of background when view is showing
	}
	
	UIImage *backgroundImage = nil;
	UIColor *backgroundColor = nil;
	
	switch (self.backgroundType) {
		case KVNProgressBackgroundTypeSolid:
			backgroundImage = [UIImage emptyImage];
			backgroundColor = self.backgroundColor;
			break;
		case KVNProgressBackgroundTypeBlurred:
			backgroundImage = [self blurredScreenShot];
			backgroundColor = [UIColor clearColor];
			break;
	}
	
	self.backgroundImageView.image = backgroundImage;
	self.backgroundImageView.backgroundColor = backgroundColor;
}

- (void)addViewToViewHierarchyIfNeeded
{
	UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
	
	if (![self isVisible]) {
		[keyWindow addSubview:self];
		[keyWindow bringSubviewToFront:self];
		
		self.translatesAutoresizingMaskIntoConstraints = NO;
		[keyWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[self]|"
																		  options:kNilOptions
																		  metrics:nil
																			views:@{@"self" : self}]];
		[keyWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[self]|"
																		  options:kNilOptions
																		  metrics:nil
																			views:@{@"self" : self}]];
		
		self.alpha = 0.0f;
		self.contentView.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
		
		[UIView animateWithDuration:KVNFadeAnimationDuration
						 animations:^{
							 self.alpha = 1.0f;
							 self.contentView.transform = CGAffineTransformIdentity;
						 }];
	}
}

#pragma mark - Circle progress animations

- (void)animateCircleWithInfiniteLoop
{
    CABasicAnimation* rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = @(M_PI * 2.0f * KVNInfiniteLoopAnimationDuration);
    rotationAnimation.duration = KVNInfiniteLoopAnimationDuration;
    rotationAnimation.cumulative = YES;
    rotationAnimation.repeatCount = HUGE_VALF;
	
    [self.circleProgressView.layer addAnimation:rotationAnimation
										 forKey:@"rotationAnimation"];
}

#pragma mark - Progress methods

+ (void)show
{
	[self showWithStatus:nil];
}

+ (void)showWithBackgroundType:(KVNProgressBackgroundType)backgroundType
{
	[self showWithStatus:nil
		  backgroundType:backgroundType];
}

+ (void)showWithStatus:(NSString *)status
{
	[self showWithStatus:status
		  backgroundType:KVNProgressBackgroundTypeBlurred];
}

+ (void)showWithStatus:(NSString *)status
		backgroundType:(KVNProgressBackgroundType)backgroundType
{
	[[self sharedView] showProgress:KVNProgressIndeterminate
							 status:status
					 backgroundType:backgroundType];
}

+ (void)showProgress:(CGFloat)progress
{
	[self showProgress:progress
				status:nil];
}

+ (void)showProgress:(CGFloat)progress
			  status:(NSString*)status
{
	[self showProgress:progress
				status:status
		backgroundType:KVNProgressBackgroundTypeBlurred];
}

+ (void)showProgress:(CGFloat)progress
			  status:(NSString*)status
	  backgroundType:(KVNProgressBackgroundType)backgroundType
{
	[[self sharedView] showProgress:progress
							 status:status
					 backgroundType:backgroundType];
}

- (void)showProgress:(CGFloat)progress
			  status:(NSString *)status
	  backgroundType:(KVNProgressBackgroundType)backgroundType
{
	self.progress = progress;
	self.indeterminate = (progress == KVNProgressIndeterminate);
	self.status = [status copy];
	self.backgroundType = backgroundType;
	
	[self setupUI];
	
	[self addViewToViewHierarchyIfNeeded];
	
	[UIApplication sharedApplication].keyWindow.userInteractionEnabled = NO;
}

+ (void)dismiss
{
	KVNProgress *progressView = [self sharedView];
	
	[UIView animateWithDuration:KVNFadeAnimationDuration
					 animations:^{
						 progressView.alpha = 0.0f;
					 } completion:^(BOOL finished) {
						[progressView removeFromSuperview];
						 [UIApplication sharedApplication].keyWindow.userInteractionEnabled = YES;
					 }];
}

#pragma mark - Update

+ (void)updateStatus:(NSString*)status
{
	[[self sharedView] updateStatus:status];
}

- (void)updateStatus:(NSString *)status
{
	if ([self isVisible]) {
		[UIView animateWithDuration:KVNLayoutAnimationDuration
						 animations:^{
							 [self setupStatus:status];
						 }];
	} else {
		[self setupStatus:status];
	}
}

+ (void)updateProgress:(CGFloat)progress
		   animated:(BOOL)animated
{
	[[self sharedView] updateProgress:progress
							 animated:animated];
}

- (void)updateProgress:(CGFloat)progress
		   animated:(BOOL)animated
{
	// Boundry correctness
    progress = MIN(progress, 1.0f);
    progress = MAX(progress, 0.0f);
	
	if (animated) {
		CABasicAnimation *progressAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
		
		progressAnimation.duration = KVNProgressAnimationDuration;
		progressAnimation.removedOnCompletion = NO;
		progressAnimation.fillMode = kCAFillModeBoth;
		progressAnimation.fromValue = @(self.progress);
		progressAnimation.toValue = @(progress);
		progressAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		
		[self.circleProgressLineLayer addAnimation:progressAnimation
											forKey:@"strokeEnd"];
	} else {
		self.circleProgressLineLayer.strokeEnd = progress;
	}
	
	self.progress = progress;
}

#pragma mark - Helpers

- (UIImage *)blurredScreenShot
{
	UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
	
	UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, 0);
	
	[keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:NO];
	UIImage *blurredScreenShot = UIGraphicsGetImageFromCurrentImageContext();
	
	UIGraphicsEndImageContext();
	
	blurredScreenShot = [blurredScreenShot applyTintEffectWithColor:self.backgroundTintColor];
	
	return blurredScreenShot;
}

#pragma mark - Information

- (BOOL)isVisible
{
	return (self.superview != nil);
}

+ (BOOL)isVisible
{
	return [[self sharedView] isVisible];
}

#pragma mark - UIAppearance getters

- (UIColor *)backgroundColor
{
	UIColor *appearanceColor = [[[self class] appearance] backgroundColor];
	
	if (appearanceColor) {
		_backgroundColor = appearanceColor;
	}
	
	return _backgroundColor;
}

- (UIColor *)backgroundTintColor
{
	UIColor *appearanceColor = [[[self class] appearance] backgroundTintColor];
	
	if (appearanceColor) {
		_backgroundTintColor = appearanceColor;
	}
	
	return _backgroundTintColor;
}

- (UIColor *)circleStrokeForegroundColor
{
	UIColor *appearanceColor = [[[self class] appearance] circleStrokeForegroundColor];
	
	if (appearanceColor) {
		_circleStrokeForegroundColor = appearanceColor;
	}
	
	return _circleStrokeForegroundColor;
}

- (UIColor *)circleStrokeBackgroundColor
{
	UIColor *appearanceColor = [[[self class] appearance] circleStrokeBackgroundColor];
	
	if (appearanceColor) {
		_circleStrokeBackgroundColor = appearanceColor;
	}
	
	return _circleStrokeBackgroundColor;
}

- (UIColor *)circleFillBackgroundColor
{
	UIColor *appearanceColor = [[[self class] appearance] circleFillBackgroundColor];
	
	if (appearanceColor) {
		_circleFillBackgroundColor = appearanceColor;
	}
	
	return _circleFillBackgroundColor;
}

- (UIColor *)statusColor
{
	UIColor *appearanceColor = [[[self class] appearance] statusColor];
	
	if (appearanceColor) {
		_statusColor = appearanceColor;
	}
	
	return _statusColor;
}

- (UIFont *)statusFont
{
	UIFont *appearanceFont = [[[self class] appearance] statusFont];
	
	if (appearanceFont) {
		_statusFont = appearanceFont;
	}
	
	return _statusFont;
}

- (CGFloat)circleSize
{
	CGFloat appearanceCircleSize = [[[self class] appearance] circleSize];
	
	if (appearanceCircleSize != 0) {
		_circleSize = appearanceCircleSize;
	}
	
	return _circleSize;
}

- (CGFloat)lineWidth
{
	CGFloat appearanceLineWidth = [[[self class] appearance] lineWidth];
	
	if (appearanceLineWidth != 0) {
		_lineWidth = appearanceLineWidth;
	}
	
	return _lineWidth;
}

@end