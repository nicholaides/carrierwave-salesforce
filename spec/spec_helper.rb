$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'carrierwave-salesforce'
require 'spec'
require 'spec/autorun'

Spec::Runner.configure do |config|
  
end

def file_path(file_name)
  File.expand_path(File.join(File.dirname(__FILE__),'/files/',file_name))
end