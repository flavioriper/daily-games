// The App Store's own rating sheet for iOS (core/review.gd decides when).
// iOS decides whether it actually shows: at most three times in 365 days per
// person, never in TestFlight, and it says nothing either way. The same
// method as the Android plugin (native/store_review/android). Built by
// tools/build_store_review.sh against ~/dev/godot-4.7-src's headers.

#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/object/object.h"

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

class StoreReview : public Object {
	GDCLASS(StoreReview, Object);

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("request"), &StoreReview::request);
	}

public:
	void request() {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIWindowScene *scene = nil;
			for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
				if (s.activationState == UISceneActivationStateForegroundActive && [s isKindOfClass:UIWindowScene.class]) {
					scene = (UIWindowScene *)s;
					break;
				}
			}
			if (scene == nil) {
				return;
			}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			// Deprecated from iOS 18 for StoreKit 2's Swift-only AppStore.requestReview;
			// it still shows the same sheet, and the game links no Swift.
			[SKStoreReviewController requestReviewInScene:scene];
#pragma clang diagnostic pop
		});
	}
};

static StoreReview *store_review = nullptr;

void initialize_store_review_module() {
	GDREGISTER_CLASS(StoreReview);
	store_review = memnew(StoreReview);
	Engine::get_singleton()->add_singleton(Engine::Singleton("StoreReview", store_review));
}

void uninitialize_store_review_module() {
	if (store_review) {
		memdelete(store_review);
		store_review = nullptr;
	}
}
