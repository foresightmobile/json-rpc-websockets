Pod::Spec.new do |s|
  s.name             = 'JSONRPCWebSockets'
  s.version          = '1.0.0'
  s.summary          = 'WebSocket Client'
  s.homepage         = 'https://github.com/foresightmobile/json-rpc-websockets'
  s.license          = { :type => 'MIT', :file => 'LICENSE.txt' }
  s.author           = 'Bandwidth'
  
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'
  s.source           = { :git => 'https://github.com/foresightmobile/json-rpc-websockets.git', :tag => s.version.to_s }
  s.source_files = 'Sources/JSONRPCWebSockets/**/*'
end
