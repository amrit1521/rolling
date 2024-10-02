/*
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
 */

package com.gotmytag.pointhunter;

import android.os.Bundle;
import org.apache.cordova.*;

public class PointHunter extends CordovaActivity
{
    private static final String BASE64_PUBLIC_KEY = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApjmbi7Eo38f7+dqaiq66ylzhsIxDaoRJmrlLH68eqVt2N5lkBvJ1Swo+5bqPEh80BjsHY4pzT+h8gDwONrmWgjAN+3CxtSUSulGKUZUU1oaOJQgpzYWahycxvp/k3SW0SODv1UNlLudp/rYiCcb5ubI8iwF/0CYU9fOS+W3P0qxsiv9mwznVfzPkZ7z65YSv+ALoCvtQZkvnha7Pe1qmPkP/KK8OHnnQZSL8F6OJ7hX2jNx6Y9CVke2Xx2bCETBJm3myY0WQaJcFsRpoDlaZULdWT0i4DvMn9dUDsRkpRJTPLbwJ4K/g36i9JF/vYX6l5zOFOkJhNX2bbA92R22/aQIDAQAB"; //truncated for this example

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        super.init();
        // Set by <content src="index.html" /> in config.xml
        super.loadUrl(Config.getStartUrl());
        //super.loadUrl("file:///android_asset/www/index.html");
    }
}

