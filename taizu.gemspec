Gem::Specification.new do |s|
  s.name = 'taizu'
  s.version = '0.1'
  s.summary = 'A ruby interface to the Temujin Gearman interface'
  s.description = 'Provides client and worker APIs to use Ruby clients or workers with Temujin/Gearman jobs.  Also supplies a RESTful web service to Temujin\'s Job Tracker, eliminating the need for local database libraries as well as a means to start remote workers.'
  s.authors = ['Ross Singer']
  s.email = 'ross.singer@talis.com'

  s.files = %w(README) + Dir.glob('lib/**/*.rb') + Dir.glob('bin/*') + Dir.glob('examples/**/*.rb') + Dir.glob('lib/**/*.ru')
  s.require_paths = %w(lib)
  s.executables << 'taizu'
  s.extensions = %w()
  s.test_files = %w()
  s.has_rdoc = false

  s.required_ruby_version = '>= 1.8.7'
  s.requirements = []
  s.add_runtime_dependency 'gearman-ruby', '>= 3.0.4'
  s.add_runtime_dependency 'uuid', '>= 2.3.4'
  s.add_runtime_dependency 'dm-core', '>= 1.1.0'
  s.add_runtime_dependency 'dm-migrations', '>= 1.1.0'
  s.add_runtime_dependency 'dm-serializer', '>= 1.1.0' 
  s.add_runtime_dependency 'dm-rest-adapter', '>= 1.1.0'  
  s.add_runtime_dependency 'addressable', '>= 2.2'  
  s.add_runtime_dependency 'net-http-digest_auth', '>= 1.1.1'    
  s.add_runtime_dependency 'sinatra', '>= 1.2.6'      
  s.add_runtime_dependency 'rack-conneg', '>= 0.1.4'    
  s.add_runtime_dependency 'crack', '>= 0.3.1'      
end