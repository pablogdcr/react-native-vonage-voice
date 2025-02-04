import type { ConfigPlugin } from 'expo/config-plugins';
import {
  withAndroidManifest,
  withAppBuildGradle,
  withProjectBuildGradle,
} from 'expo/config-plugins';
import { mergeContents } from '@expo/config-plugins/build/utils/generateCode';
import type { StringBoolean } from '@expo/config-plugins/build/android/Manifest';

const withAndroidVonageVoice: ConfigPlugin = (config) => {
  // Add required permissions to AndroidManifest.xml
  config = withAndroidManifest(config, (androidConfig) => {
    const mainApplication = androidConfig.modResults.manifest?.application?.[0];
    const manifest = androidConfig.modResults.manifest;

    // Add permissions
    if (!manifest['uses-permission']) {
      manifest['uses-permission'] = [];
    }

    const permissions = [
      'android.permission.INTERNET',
      'android.permission.RECORD_AUDIO',
      'android.permission.MODIFY_AUDIO_SETTINGS',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.BLUETOOTH',
      'android.permission.BLUETOOTH_CONNECT',
      'android.permission.MANAGE_OWN_CALLS',
      'android.permission.READ_PHONE_STATE',
    ];

    permissions.forEach((permission) => {
      if (
        !manifest['uses-permission']?.find(
          (item: { $: { 'android:name': string } }) =>
            item.$['android:name'] === permission
        )
      ) {
        manifest['uses-permission']?.push({
          $: {
            'android:name': permission,
          },
        });
      }
    });

    // Add features
    manifest['uses-feature'] = manifest['uses-feature'] || [];
    const features = [
      {
        $: {
          'android:name': 'android.hardware.telephony',
          'android:required': 'false' as StringBoolean,
        },
      },
      {
        $: {
          'android:name': 'android.hardware.bluetooth',
          'android:required': 'false' as StringBoolean,
        },
      },
      {
        $: {
          'android:name': 'android.hardware.microphone',
          'android:required': 'true' as StringBoolean,
        },
      },
    ];

    features.forEach((feature) => {
      if (
        !manifest['uses-feature']?.find(
          (f: { $: { 'android:name': string } }) =>
            f.$['android:name'] === feature.$['android:name']
        )
      ) {
        manifest['uses-feature']?.push(feature);
      }
    });

    // Add Telecom service
    if (!mainApplication?.service) {
      mainApplication!.service = [];
    }

    const telecomService = {
      '$': {
        'android:name':
          'com.vonagevoice.controller.call.VonageConnectionService',
        'android:permission':
          'android.permission.BIND_TELECOM_CONNECTION_SERVICE',
        'android:exported': 'true' as StringBoolean,
      },
      'intent-filter': [
        {
          action: [
            {
              $: {
                'android:name': 'android.telecom.ConnectionService',
              },
            },
          ],
        },
      ],
    };

    // Add Firebase service
    const firebaseService = {
      '$': {
        'android:name': 'com.vonagevoice.push.VonagePushMessageService',
        'android:exported': 'false' as StringBoolean,
      },
      'intent-filter': [
        {
          action: [
            {
              $: {
                'android:name': 'com.google.firebase.MESSAGING_EVENT',
              },
            },
          ],
        },
      ],
    };

    if (
      !mainApplication?.service?.find(
        (service: { $: { 'android:name': string } }) =>
          service.$['android:name'] === telecomService.$['android:name']
      )
    ) {
      mainApplication?.service?.push(telecomService);
    }

    if (
      !mainApplication?.service?.find(
        (service: { $: { 'android:name': string } }) =>
          service.$['android:name'] === firebaseService.$['android:name']
      )
    ) {
      mainApplication?.service?.push(firebaseService);
    }

    return androidConfig;
  });

  // Add Vonage SDK to project build.gradle
  config = withProjectBuildGradle(config, (gradleConfig) => {
    const buildGradle = gradleConfig.modResults.contents;

    // Add maven repository
    if (
      !buildGradle.includes(
        'https://artifactory.vonage.com/artifactory/libs-release'
      )
    ) {
      gradleConfig.modResults.contents = mergeContents({
        tag: 'vonage-maven-repository',
        src: buildGradle,
        newSrc:
          '        maven { url "https://artifactory.vonage.com/artifactory/libs-release" }',
        anchor: /\s+mavenCentral\(\)/,
        offset: 1,
        comment: '//',
      }).contents;
    }

    return gradleConfig;
  });

  // Add Vonage dependencies to app build.gradle
  config = withAppBuildGradle(config, (gradleConfig) => {
    const buildGradle = gradleConfig.modResults.contents;

    // Add Vonage SDK dependency
    if (!buildGradle.includes('com.vonage:client-sdk-voice')) {
      gradleConfig.modResults.contents = mergeContents({
        tag: 'vonage-sdk-dependency',
        src: buildGradle,
        newSrc: '    implementation "com.vonage:client-sdk-voice:1.7.2"',
        anchor: /dependencies\s*{/,
        offset: 1,
        comment: '//',
      }).contents;
    }

    return gradleConfig;
  });

  return config;
};

export default withAndroidVonageVoice;
