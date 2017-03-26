Pod::Spec.new do |s|

  s.name                = "AsyncNinja"
  s.version             = "1.0.0-beta7"
  s.summary             = "Swift library for concurrency and reactive programming"
  s.homepage            = "http://async.ninja"
  s.license             = "MIT"
  s.author              = { "Anton Mironov" => "antonvmironov@gmail.com" }
  s.social_media_url    = "https://twitter.com/AntonMironov"

  s.ios.deployment_target       = "8.0"
  s.osx.deployment_target       = "10.10"
  s.watchos.deployment_target   = "2.0"
  s.tvos.deployment_target      = "9.0"

  s.source_files        = 'Sources/*.swift'
  s.source              = { :git => "https://github.com/AsyncNinja/AsyncNinja.git", :tag => s.version }
  s.requires_arc        = true

end
