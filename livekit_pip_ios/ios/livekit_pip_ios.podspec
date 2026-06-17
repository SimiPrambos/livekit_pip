#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'livekit_pip_ios'
  s.version          = '0.0.1'
  s.summary          = 'An iOS implementation of the livekit_pip plugin.'
  s.description      = <<-DESC
  An iOS implementation of the livekit_pip plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'Dev Kaffah' => 'email@example.com' }
  s.source           = { :path => '.' }  
  s.source_files = 'livekit_pip_ios/Sources/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '6.1'
end
