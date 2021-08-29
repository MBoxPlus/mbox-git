
require 'yaml'
yaml = YAML.load_file('../manifest.yml')
name = yaml["NAME"]
name2 = name.sub('MBox', 'mbox').underscore
version = ENV["VERSION"] || yaml["VERSION"]

Pod::Spec.new do |spec|
  spec.name         = "#{name}"
  spec.version      = "#{version}"
  spec.summary      = "Git Plugin for MBox."
  spec.description  = <<-DESC
    Include git function and libgit2.
                   DESC

  spec.homepage     = "https://github.com/MBoxPlus/#{name2}"
  spec.license      = "MIT"
  spec.author       = { `git config user.name`.strip => `git config user.email`.strip }
  spec.source       = { :git => "git@github.com:MBoxPlus/#{name2}.git", :tag => "#{spec.version}" }

  spec.source_files = "#{name}/*.{h,m,swift}", "#{name}/**/*.{h,m,swift}"

  spec.frameworks = "CoreFoundation", "Security"

  yaml['DEPENDENCIES']&.each do |name|
    spec.dependency name
  end
  yaml['FORWARD_DEPENDENCIES']&.each do |name, _|
    spec.dependency name
  end

  spec.dependency "SwiftGit2-MBox", "~> 1.5.1"
  spec.user_target_xcconfig = {
    "FRAMEWORK_SEARCH_PATHS" => "\"$(DSTROOT)/MBoxGit/MBoxGit.framework/Versions/A/Frameworks\""
  }
end
