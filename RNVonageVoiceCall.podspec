require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))


Pod::Spec.new do |s|
  s.name             = 'RNVonageVoiceCall'
  s.version          = package['version']
  s.summary          = package['description']
  s.homepage         = package['homepage']
  s.license          = package['license']
  s.author           = package['author']
  s.source           = { :git => package['repository']['url'], :tag => "v#{s.version}" }
  s.source_files     = 'ios/**/*.{h,m,swift}'
  s.platform         = :ios, "13.4"
  s.swift_version    = '5.4'
  s.static_framework = true
  s.dependency 'React'

  s.dependency 'VonageClientSDKVoice', '1.6.2'

  s.resource_bundles = { 'RNVonageVoiceCall_Privacy' => ['ios/PrivacyInfo.xcprivacy'] }
end
