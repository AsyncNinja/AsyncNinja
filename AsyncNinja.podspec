Pod::Spec.new do |s|

  s.name                = 'AsyncNinja'
  s.version             = '1.2.1'
  s.summary             = 'A complete set of primitives for concurrency and reactive programming on Swift'
  s.homepage            = 'http://async.ninja'
  s.license             = { :type => 'MIT', :file => 'LICENSE' }
  s.author              = { 'Anton Mironov' => 'antonvmironov@gmail.com' }
  s.social_media_url    = 'https://twitter.com/AntonMironov'

  s.frameworks                   = 'WebKit', 'CoreData', 'SystemConfiguration'
  s.ios.framework                = 'UIKit'
  s.ios.deployment_target        = '8.0'

  s.osx.framework                = 'AppKit'
  s.osx.deployment_target        = '10.10'

  s.watchos.frameworks           = 'WatchKit'
  s.watchos.deployment_target    = '2.0'

  s.tvos.frameworks              = 'UIKit'
  s.tvos.deployment_target       = '9.0'

  s.source_files        = 'Sources/*.swift'
  s.source              = { :git => 'https://github.com/AsyncNinja/AsyncNinja.git', :tag => s.version }
  s.requires_arc        = true
  s.documentation_url   = 'http://docs.async.ninja'

end
