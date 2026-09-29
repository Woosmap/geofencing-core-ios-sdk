Pod::Spec.new do |s|
  s.name = 'WoosmapGeofencingCore'
  s.version = '4.5.0'
  s.license = 'BSD'
  s.summary = 'Geofencing in Swift'
  s.homepage = 'https://github.com/woosmap/geofencing-core-ios-sdk'
  s.authors = { 'Woosmap' => 'https://developers.woosmap.com/support/contact/'}
  s.source = { :git => 'https://github.com/woosmap/geofencing-core-ios-sdk.git', :tag => s.version }
  s.documentation_url = 'https://github.com/woosmap/geofencing-core-ios-sdk'

  s.ios.deployment_target = '15.0'

  # 5.9 is the real floor: the sources reference CLMonitor, which only exists in
  # the iOS 17 SDK, so nothing older than Xcode 15 can compile this pod at all.
  s.swift_versions = ['5.9']
  s.source_files = 'Sources/WoosmapGeofencing/*.swift', 'Sources/WoosmapGeofencing/Business Logic/*.swift',"Sources/WoosmapGeofencing/Surge/**/*.swift"
  s.resources = 'Sources/WoosmapGeofencing/Business Logic/Woosmap.xcdatamodeld','Sources/WoosmapGeofencing/*.{xcprivacy}'
end
