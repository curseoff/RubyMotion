require 'motion/project/app'
require 'motion/project/config'
require 'motion/project/builder'
require 'motion/project/vendor'

desc "Build the project, then run the simulator"
task :default => :simulator

App = Motion::Project::App

namespace :build do
  desc "Build the simulator version"
  task :simulator do
    App.build('iPhoneSimulator')
  end

  desc "Build the iOS version"
  task :ios do
    App.build('iPhoneOS')
    App.codesign('iPhoneOS')
  end

  desc "Build everything"
  task :all => [:simulator, :ios]
end

desc "Run the simulator"
task :simulator => ['build:simulator'] do
  app = App.config.app_bundle('iPhoneSimulator')
  sdk_version = App.config.sdk_version

  # Cleanup the simulator application sandbox, to avoid having old resource files there.
  sim_apps = File.expand_path("~/Library/Application Support/iPhone Simulator/#{sdk_version}/Applications")
  Dir.glob("#{sim_apps}/**/*.app").each do |app_bundle|
    if File.basename(app_bundle) == File.basename(app)
      rm_rf File.dirname(app_bundle)
      break
    end  
  end

  # Launch the simulator.
  sim = File.join(App.config.bindir, 'sim')
  debug = (ENV['debug'] || '0') == '1' ? 1 : 0
  family = App.config.device_family_ints[0]
  sh "#{sim} #{debug} #{family} #{sdk_version} \"#{app}\""
end

desc "Create an .ipa archive"
task :archive => ['build:ios'] do
  tmp = "/tmp/ipa_root"
  sh "/bin/rm -rf #{tmp}"
  sh "/bin/mkdir -p #{tmp}/Payload"
  sh "/bin/cp -r \"#{App.config.app_bundle('iPhoneOS')}\" #{tmp}/Payload"
  Dir.chdir(tmp) do
    sh "/bin/chmod -R 755 Payload"
    sh "/usr/bin/zip -q -r archive.zip Payload"
  end
  sh "/bin/cp #{tmp}/archive.zip \"#{App.config.archive}\""
end

desc "Deploy on the device"
task :deploy => :archive do
  deploy = File.join(App.config.bindir, 'deploy')
  flags = Rake.application.options.trace ? '-d' : ''
  sh "#{deploy} #{flags} \"#{App.config.archive}\""
end

desc "Clear build objects"
task :clean do
  rm_rf(App.config.build_dir)
end

desc "Show project config"
task :config do
  map = App.config.variables
  map.keys.sort.each do |key|
    puts key.ljust(22) + " : #{map[key].inspect}"
  end
end
