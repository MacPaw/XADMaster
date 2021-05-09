Pod::Spec.new do |s|
  s.name     = 'XADMaster'
  s.version  = '1.10.7'
  s.license  =  { :type => 'LGPL', :file => 'LICENSE' }
  s.summary  = 'Objective-C library for archive and file unarchiving and extraction'
  s.homepage = 'https://github.com/iComics/XADMaster'
  s.authors  = 'Dag Ågren', 'MacPaw Inc.', 'Tim Oliver'
  s.source   = { :http => 'https://github.com/iComics/XADMaster/releases/download/1.10.7/XADMaster.zip' }
  s.platform = :ios
  s.ios.deployment_target  = '9.0'
  s.ios.vendored_frameworks = 'XADMaster.xcframework'
end
