module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.vonagevoice.VonageVoicePackage;',
        packageInstance: 'new VonageVoicePackage()',
      },
      ios: {
        podspecPath: './react-native-vonage-voice.podspec',
      },
    },
  },
};
