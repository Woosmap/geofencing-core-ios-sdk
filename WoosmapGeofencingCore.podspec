Pod::Spec.new do |s|
  s.name = 'WoosmapGeofencingCore'
  s.version = '4.3.0'
  s.license = 'BSD'
  s.summary = 'Geofencing in Swift'
  s.homepage = 'https://github.com/woosmap/geofencing-core-ios-sdk'
  s.authors = { 'Web Geo Services' => 'https://developers.woosmap.com/support/contact/'}
  s.source = { :git => 'https://github.com/woosmap/geofencing-core-ios-sdk.git', :tag => s.version }
  s.documentation_url = 'https://github.com/woosmap/geofencing-core-ios-sdk'

  s.ios.deployment_target = '13.0'

  s.swift_versions = ['5.1', '5.2']
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.source_files = 'Sources/WoosmapGeofencing/*.swift', 'Sources/WoosmapGeofencing/Business Logic/*.swift',"Sources/WoosmapGeofencing/Surge/**/*.swift"
  s.resources = 'Sources/WoosmapGeofencing/Business Logic/Woosmap.xcdatamodeld','Sources/WoosmapGeofencing/*.{xcprivacy}'
end
