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

  # The Swift *language mode*, which is what CocoaPods writes into the target's
  # SWIFT_VERSION — the same 5.0 the Xcode project uses. A compiler release such as
  # 5.10 is not a valid value here and fails the integration before these sources are
  # reached.
  #
  # The compiler floor is a separate thing and is not expressed in this file: the
  # sources need Xcode 16 and Swift 5.10 for CLServiceSession, the iOS 18
  # CLMonitor.Event flags and nonisolated(unsafe). Package.swift states that with its
  # swift-tools-version; a pod has nowhere to declare it, so it is documented here.
  s.swift_versions = ['5.0']
  s.source_files = 'Sources/WoosmapGeofencing/*.swift', 'Sources/WoosmapGeofencing/Business Logic/*.swift',"Sources/WoosmapGeofencing/Surge/**/*.swift"
  s.resources = 'Sources/WoosmapGeofencing/Business Logic/Woosmap.xcdatamodeld','Sources/WoosmapGeofencing/*.{xcprivacy}'
end
