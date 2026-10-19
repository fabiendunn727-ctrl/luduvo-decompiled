package com.luduvo.client;

import android.app.Application;

/**
 * Loads the native engine library as early as possible so the first frame
 * does not pay for the library load.
 */
public final class LuduvoApplication extends Application {

    @Override
    public void onCreate() {
        super.onCreate();
        LuduvoEngine.loadLibrary();
    }
}
