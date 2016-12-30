Pod::Spec.new do |s|

  s.name         = "AsyncNinja"
  s.version      = "0.4-beta2"
  s.summary      = "AsyncNinja is a concurrency library for Swift."
  s.description  = <<-DESC
Toolset for typesafe, threadsafe, memory leaks safe concurrency in Swift 3. Contains primitives: Future, Channel, Executor, ExecutionContext, Fallible, Cache
                   DESC
  s.homepage     = "http://async.ninja"
  s.license      = "MIT"
  s.author             = { "Anton Mironov" => "antonvmironov@gmail.com" }
  s.social_media_url   = "https://twitter.com/AntonMironov"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"

  s.source_files = 'Sources/*.swift'

  s.source       = { :git => "https://github.com/AsyncNinja/AsyncNinja.git", :tag => s.version }
  s.requires_arc = true

end
