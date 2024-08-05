import { useEffect, useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  NativeEventEmitter,
} from 'react-native';
import {
  VonageEventEmitter,
  RNVonageVoiceCall,
} from 'react-native-vonage-voice';

const eventEmitter = new NativeEventEmitter(VonageEventEmitter);

export default function App() {
  const [connectionStatus, setConnectionStatus] = useState('Disconnected');

  useEffect(() => {
    const subscription = eventEmitter.addListener('receivedInvite', (event) => {
      console.log('receivedInvite:', event);
    });

    // Clean up the subscription on unmount
    return () => {
      subscription.remove();
    };
  }, []);

  const login = async () => {
    const response = await RNVonageVoiceCall.createSession(
      'eyJ0eXBlIjoiSldUIiwiYWxnIjoiUlMyNTYifQ.eyJhcHBsaWNhdGlvbl9pZCI6IjgwOTkwMzViLTMyM2EtNGJmZi05ZjFkLWMzNDZhNzQwZDhhZiIsImlhdCI6MTcyMjYxMTg3MCwic3ViIjoidXNyLTEyRTVGQzdBN0IxNEQyNzAxRDM0MDgzMjE0RkQ3NDU1NjczRDQ4QjMiLCJhY2wiOnsicGF0aHMiOnsiLyovcnRjLyoqIjp7fSwiLyovdXNlcnMvKioiOnt9LCIvKi9jb252ZXJzYXRpb25zLyoqIjp7fSwiLyovc2Vzc2lvbnMvKioiOnt9LCIvKi9kZXZpY2VzLyoqIjp7fSwiLyova25vY2tpbmcvKioiOnt9LCIvKi9sZWdzLyoqIjp7fX19LCJqdGkiOiJkMzQwZmY0YS03YmNmLTRmNDgtODYzMS02OTkwMzZkZDM4MTMifQ.ZlZnrV4vMwS7kobgatwohu9BD7lh-KVUY6_utWX9Y57bBNCV2wAYxfQ-5nysQ5ZaAen9_OklRry9qzdMTuCyUNU8VORjv4xOS_uGd3ajE2RoZyuWPHsmCOtpo3QwyWIl6QIkOc1hTX3G389Tac6auabs8WoEfYpGE-SIdmRw2C4lTe_1CQj4_9IRSnXQJBUrGWesEN54u-zF4ddRrPUIOI6YbAUnfmkgORJK03h4TytmWvkghLGXzQPgYxgMCnSiC3rgFHY7xpXEVYRlED-FIXJYyOM41ETL-S_8gNfUyLgYeRlupMKHXxiBXvA7HriPyRJ9DMag--eZu-GvogNiJQ',
      'EU'
    );

    response && setConnectionStatus(response);
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity onPress={login}>
        <Text>Login</Text>
      </TouchableOpacity>

      <Text>{connectionStatus}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
