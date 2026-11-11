package com.peeplet.storereview;

import android.app.Activity;
import android.util.Log;

import com.google.android.play.core.review.ReviewInfo;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Play's in-app rating sheet. core/review.gd decides when to ask; Play decides
 * whether the sheet actually shows (it keeps its own quota and says nothing
 * either way), so this is fire and forget. A build not installed from Play
 * (an App Distribution APK) gets no sheet.
 */
public class StoreReviewPlugin extends GodotPlugin {
	private static final String TAG = "StoreReview";

	public StoreReviewPlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "StoreReview";
	}

	@UsedByGodot
	public void request() {
		final Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		activity.runOnUiThread(() -> {
			final ReviewManager manager = ReviewManagerFactory.create(activity);
			manager.requestReviewFlow().addOnCompleteListener(task -> {
				if (!task.isSuccessful()) {
					Log.w(TAG, "review flow unavailable", task.getException());
					return;
				}
				ReviewInfo info = task.getResult();
				manager.launchReviewFlow(activity, info);
			});
		});
	}
}
