// import { useState } from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
// import RNVonageVoiceCall from 'react-native-vonage-voice';

export default function App() {
  // const [connectionStatus, setConnectionStatus] = useState('Disconnected');

  // useEffect(() => {
  //   TODO: rewrite example
  //   const subscription = RNVonageVoiceCall.onReceivedInvite((event) => {
  //     console.log('receivedInvite:', event);
  //   });

  //   return () => {
  //     subscription.remove();
  //   };
  // }, []);

  const login = async () => {
    // TODO: rewrite example
    // const response = await RNVonageVoiceCall.createSession(
    //   '<YOUR_TOKEN>',
    //   'EU'
    // );
    // response && setConnectionStatus(response);
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity onPress={login}>
        <Text>Login</Text>
      </TouchableOpacity>

      {/* <Text>{connectionStatus}</Text> */}
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
