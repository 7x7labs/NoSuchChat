Pod::Spec.new do |s|
  s.name         = "curve25519-donna"
  s.version      = "1.3-dev"
  s.summary      = "Implementations of a fast Elliptic-curve Diffie-Hellman primitive"
  s.homepage     = "http://code.google.com/p/curve25519-donna"
  s.author       = { "Adam Langley" => "agl@chromium.org" }
  s.source       = { :git => "https://github.com/agl/curve25519-donna.git" }
  s.license      = '3-clause BSD License'
  s.description  = "Implementations of a fast Elliptic-curve Diffie-Hellman primitive"

  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'

  s.source_files = 'curve25519-donna.c'
end
