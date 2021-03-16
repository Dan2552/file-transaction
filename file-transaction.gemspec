lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "file-transaction/version"

Gem::Specification.new do |spec|
  spec.name          = "file-transaction"
  spec.version       = FileTransaction::VERSION
  spec.authors       = ["Daniel Inkpen"]
  spec.email         = ["dan2552@gmail.com"]

  spec.summary       = "ActiveRecord-like transaction block for files in a directory"
  spec.description   = "Copy a directory to a temp directory temporarily to perform mutations, to then copy it back. If any exceptions are raised within the block, the changes will not be copied back."
  spec.homepage      = "https://github.com/Dan2552/file-transaction"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
end
