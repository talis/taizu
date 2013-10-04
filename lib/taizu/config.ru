require 'yaml'
require 'digest/md5'
require File.dirname(__FILE__) + '/server'

class EnvironmentNotSetError < StandardError;end
class ConfigurationError < StandardError;end
unless ENV['TAIZU_HOME'] || File.exist?(ENV['HOME']+"/.taizu/taizud.yml")
  raise EnvironmentNotSetError, "Environment variable TAIZU_HOME not set!" unless ENV['TAIZU_HOME']
end
CONFIG = YAML.load_file case
when ENV['TAIZU_HOME'] then ENV['TAIZU_HOME']+"/taizud.yml"
else ENV['HOME']+"/.taizu/taizud.yml"
end
raise ConfigurationError, "No configuration set." if CONFIG.empty?
if CONFIG['database']
  Taizu.database=CONFIG['database']
else
  puts "No database set.  RESTful JobTracker will be disabled."
end
if CONFIG['accounts'] && CONFIG['authentication']
  def authenticate_app
    app = Rack::Auth::Digest::MD5.new(Server.new) do |username|
      CONFIG['accounts'][username]
    end
    app.realm = CONFIG['authentication']['realm']
    app.opaque = CONFIG['authentication']['opaque']
    app.passwords_hashed = CONFIG['authentication']['hash_passwords']
    app
  end
else
  raise ConfigurationError, "No accounts/authentication configuration set."
end

app = Rack::URLMap.new({
  '/' => authenticate_app
})

run app