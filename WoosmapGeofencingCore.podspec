Pod::Spec.new do |s|
  s.name = 'WoosmapGeofencingCore'
  s.version = '3.0.6'
  s.license = 'BSD'
  s.summary = 'Geofencing in Swift'
  s.homepage = 'https://github.com/woosmap/geofencing-core-ios-sdk'
  s.authors = { 'Web Geo Services' => 'https://developers.woosmap.com/support/contact/'}
  s.source = { :git => 'https://github.com/woosmap/geofencing-core-ios-sdk.git', :tag => s.version }
  s.documentation_url = 'https://github.com/woosmap/geofencing-core-ios-sdk'

  s.ios.deployment_target = '11.0'

  s.swift_versions = ['5.1', '5.2']
  s.source_files = 'Sources/WoosmapGeofencing/*.swift', 'Sources/WoosmapGeofencing/Business Logic/*.swift'
  s.dependency 'Surge', '~> 2.3.0'
  s.dependency 'RealmSwift'
  s.dependency 'Realm' 
end
