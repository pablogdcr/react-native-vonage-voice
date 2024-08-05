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
      '<YOUR_TOKEN>',
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
