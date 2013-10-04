module Taizu
  require 'yaml'
  require 'net/http'
  require 'net/http/digest_auth'
  require 'addressable/uri'
  module CLIMethods
    def set_home
      if ENV['TAIZU_HOME']
        @home = ENV['TAIZU_HOME']
      else
        @home = ENV['HOME'] + "/.taizu"
      end      
    end
    def yes?(stdin)
      case stdin.downcase
      when "y" then true
      when "yes" then true
      else false
      end
    end    
  end
  
  class Environment
    include CLIMethods
    attr_reader :home
    def initialize
      unless ARGV[1] || ARGV[1] == "help"
        puts "Usage: taizu init environment_name"
        exit!
      end
      set_home
      check_home
      
      if File.exists?(@home + "/taizu.yml")
        config = YAML.load_file(@home + "/taizu.yml")
      else
        config = {}
      end
      config["environments"] ||= {}
      if config["environments"][ARGV[1]]
        puts "Environment '#{ARGV[1]} exists!  Do you want to overwrite? (y/N)"
        answer = STDIN.gets.chomp
        unless answer.downcase == "y" || answer.downcase == "yes"
          puts "Exiting."
          exit!
        end
      end
      config["environments"][ARGV[1]] = {"gearman_servers"=>[],"database"=>nil}
      confirm = "n"
      servers = []
      until yes?(confirm)
        puts "Enter your gearman host:ports (comma delimited: localhost:4730,example.org:4735)"
        gearman = STDIN.gets.chomp
        servers = gearman.split(",")
        puts "You want to add: #{servers.join(", ")}.  Is this correct? (y/N)"
        confirm = STDIN.gets.chomp                
      end
      servers.each {|s| config["environments"][ARGV[1]]["gearman_servers"] << s.strip }
      db = nil
      confirm = "n"
      until yes?(confirm)
        puts "Enter your Temujin DB connection string.  Examples:"
        puts "\tSQLite:  sqlite:///path/to/gearman.db (only works for local instances)"
        puts "\tMySQL:  mysql://user:pass@example.org/gearman"
        puts "\tREST:  http://user:pass@example.org:4567/taizu/ (requires taizud on Temujin server)"
        db = STDIN.gets.chomp
        puts "You want to add: #{db}.  Is this correct? (y/N)"
        confirm = STDIN.gets.chomp                
      end 
      config["environments"][ARGV[1]]["database"] = db
      puts "Settings:"
      puts "\n\tEnvironment:  #{ARGV[1]}"
      puts "\n\t\tGearman servers:  #{config["environments"][ARGV[1]]["gearman_servers"].join(", ")}"
      puts "\n\t\tDatabase: #{config["environments"][ARGV[1]]["database"]}"
      puts "\nSave environment? (y/N)"
      answer = STDIN.gets.chomp
      if yes?(answer)
        unless fh = open(@home+"/taizu.yml", "w")
          puts "Error writing #{@home}/taizu.yml!"
          exit!
        end
        fh << config.to_yaml        
        fh.close

        puts "Saved!"
        exit!
      else
        puts "Environment not saved.\nExiting."
        exit!
      end
    end
    
    def check_home
      if Dir[@home].empty?
        puts "Directory #{@home} does not exist, shall I create it? (y/N)"
        answer = STDIN.gets.chomp
        unless (answer.downcase == "y" || answer.downcase == "yes")
          puts "To use a different directory, set the TAIZU_HOME environment variable to your preferred path before running 'taizu init'."
          puts "Exiting."
          exit!
        end
        puts "Creating #{@home}..."
        dirs = @home.split("/")
        path = []
        dirs.each do |dir|
          path << dir
          next if dir.nil? || dir.empty?
          unless Dir[path.join("/")].empty?
            next
          end
          next if d = Dir.mkdir(path.join("/"), 0700)
          puts "Error creating #{path.join("/")}!"
          puts "Exiting!"
          exit!
        end
      end
    end      
  end
  class WorkerLauncher
    include CLIMethods
    def initialize
      unless ARGV[1] || ARGV[1] == "help"
        puts "Usage: taizu worker environment_string [ruby vm:]path_to_worker [num_workers]"
        exit!
      end
      set_home
      home_exists?
      load_config
      env_exists?
      launch(@config["environments"][ARGV[1]])
    end
    
    def launch(env)
      unless ARGV[2]
        puts "Usage: taizu worker #{ARGV[1]} [ruby vm:]path_to_worker [num_workers]"
        exit!
      end
      (vm, file) = ARGV[2].split(":")
      unless file
        file = vm
        vm = "ruby"
      end
      pids = []
      num_workers = (ARGV[3]||1).to_i
      num_workers.times do 
        exec("export TAIZU_GEARMAN=#{env['gearman_servers'].join(",")};export TAIZU_DB=#{env['database']};/usr/bin/env #{vm} #{file}") if fork == nil
      end
      puts "#{num_workers} workers launched."
      exit!
    end
    
    def home_exists?
      if Dir[@home].empty?
        puts "Directory #{@home} does not exist.  Please run taizu init #{ARGV[1]} to set up environment."      
        puts "Exiting."
        exit!
      end
    end
    
    def load_config
      if File.exists?(@home + "/taizu.yml")
        @config = YAML.load_file(@home + "/taizu.yml")
      else
        puts "#{@home}/taizu.yml does not exist.  Please run taizu init #{ARGV[1]} to set up environment."      
        puts "Exiting."
        exit!
      end            
    end
    
    def env_exists?
      unless @config["environments"][ARGV[1]]
        puts "Environment #{ARGV[1]} does not exist.  Please run taizu init #{ARGV[1]} to set up environment."      
        puts "Exiting."
        exit!
      end        
    end
  end
  class JobLauncher
    include CLIMethods
    def initialize
      unless ARGV[1] || ARGV[1] == "help"
        puts "Usage: taizu job environment_string [ruby vm:]path_to_client"
        exit!
      end
      set_home
      home_exists?
      load_config
      env_exists?
      launch(@config["environments"][ARGV[1]])
    end
    
    def launch(env)
      unless ARGV[2]
        puts "Usage: taizu job #{ARGV[1]} [ruby vm:]path_to_worker"
        exit!
      end
      (vm, file) = ARGV[2].split(":")
      unless file
        file = vm
        vm = "ruby"
      end

      system("export TAIZU_GEARMAN=#{env['gearman_servers'].join(",")};export TAIZU_DB=#{env['database']};/usr/bin/env #{vm} #{file}")

      exit!
    end
    
    def home_exists?
      if Dir[@home].empty?
        puts "Directory #{@home} does not exist.  Please run taizu init #{ARGV[1]} to set up environment."      
        puts "Exiting."
        exit!
      end
    end
    
    def load_config
      if File.exists?(@home + "/taizu.yml")
        @config = YAML.load_file(@home + "/taizu.yml")
      else
        puts "#{@home}/taizu.yml does not exist.  Please run taizu init #{ARGV[1]} to set up environment."      
        puts "Exiting."
        exit!
      end            
    end
    
    def env_exists?
      unless @config["environments"][ARGV[1]]
        puts "Environment #{ARGV[1]} does not exist.  Please run taizu init #{ARGV[1]} to set up environment."      
        puts "Exiting."
        exit!
      end        
    end
  end  
  
  class ServerControl
    include CLIMethods
    def initialize
      unless ARGV[1] || ARGV[1] == "help"
        puts "Usage: taizu server {start|config|user|worker|help}"
        exit!
      end
      set_home
      create_home unless home_exists?        
      load_config
      case ARGV[1]
      when "start" then start
      when "config" then config
      when "user" then add_user
      when "worker" then add_worker        
      else
        puts "Usage: taizu server {start|config|user|worker|help}"
        exit!        
      end
    end
    
    def start
      if @config.empty?
        puts "No configuration set!  Running taizu server config first."
        config
      end
      file = File.dirname(__FILE__) + "/config.ru"
      options = ""
      if @config["preferred_port"]
        options << " -p #{@config["preferred_port"]}"
      end
      if @config["server"]
        options << " -s #{@config["server"]}"
      end      
      exec("export TAIZU_HOME=#{@home};/usr/bin/env rackup -D #{options} #{file}") if fork == nil
    end
    
    def config
      @config["authentication"] ||= {}
      puts "Taizu server uses Digest/MD5 authentication."
      confirm = "n"
      realm = nil
      until yes?(confirm)
        puts "Please enter an authentication realm name: (default: #{@config["authentication"]["realm"]||"Taizu Server"})"
        realm = STDIN.gets.chomp
        realm = @config["authentication"]["realm"]||"Taizu Server" if realm.empty?
        puts "You entered: #{realm} - Is this correct? (y/N)"
        confirm = STDIN.gets.chomp
      end
      @config["authentication"]["realm"] = realm
      confirm = "n"
      opaque = nil
      until yes?(confirm)
        puts "Please enter an opaque string:"
        puts  "default: #{@config["authentication"]["opaque"]}" if @config["authentication"]["opaque"]
        opaque = STDIN.gets.chomp
        opaque = @config["authentication"]["opaque"] if opaque.empty?
        if opaque.nil?
          puts "Opaque string cannot be empty!"
        else
          puts "You entered: #{opaque}\nIs this correct? (y/N)"
          confirm = STDIN.gets.chomp
        end
      end
      @config["authentication"]["opaque"] = opaque
      passwords = nil
      confirm = "n"
      until yes?(confirm)
        puts "Hash passwords on server? (Y/n)"
        p = STDIN.gets.chomp
        p = "y" if p.empty?
        passwords = yes?(p) 
        realm = @config["authentication"]["realm"]||"Taizu Server" if realm.empty?
        puts "You entered: #{passwords ? "y" : "n"} - Is this correct? (y/N)"
        confirm = STDIN.gets.chomp
      end   
      @config["authentication"]["hash_passwords"] = passwords
      port = nil
      confirm = "n"
      until yes?(confirm)
        puts "Which port would you prefer Taizu Server to run on (only applies if launched via 'taizu server start) (default: #{@config["preferred_port"]||"9292"})"
        port = STDIN.gets.chomp
        port = @config["preferred_port"]||9292 if port.empty?
        puts "You entered: #{port} - Is this correct? (y/N)"
        confirm = STDIN.gets.chomp
      end   
      @config["preferred_port"] = port.to_i      
      db = nil
      confirm = "n"
      until yes?(confirm)
        puts "Enter your Temujin DB connection string.  Examples:"
        puts "\tSQLite:  sqlite:///path/to/gearman.db (only works for local instances)"
        puts "\tMySQL:  mysql://user:pass@example.org/gearman"
        puts "default: #{@config["database"]}" if @config["database"]
        db = STDIN.gets.chomp
        db = @config["database"] if db.empty?
        if db.nil?
          puts "You must add a database connection string!"
        else
          puts "You want to add: #{db}.  Is this correct? (y/N)"
          confirm = STDIN.gets.chomp                
        end
      end   
      @config["database"] = db
      save   
      puts "Saved!"
    end
    
    def add_user
      if @config.empty?
        puts "No server configuration is set, so we need to run through the configuration options, first."
        config
      end
      @config["accounts"] ||= {}
      uname = nil
      confirm = "n"
      until yes?(confirm)
        puts "Enter a username:"
        uname = STDIN.gets.chomp
        unless uname.empty?
          puts "You entered: #{uname} - Is this correct? (y/N)"
          confirm = STDIN.gets.chomp
        end
      end
      if @config["accounts"][uname]
        puts "#{uname} exists, overwrite? (y/N)"
        unless yes?(STDIN.gets.chomp)
          puts "Exiting."
          exit!
        end
      end
      p1 = rand(100)
      p2 = rand(100) + p1
      confirm = "n"
      system "stty -echo" 
      until p1 == p2
        p1 = ""
        until !p1.empty?
          puts "Enter password:"
          p1 = STDIN.gets.chomp
        end
        p2 = ""
        until !p2.empty?
          puts "Confirm password:"
          p2 = STDIN.gets.chomp
        end
      end 
      if @config["authentication"]["hash_passwords"]
        require 'digest/md5'
        password = Digest::MD5.hexdigest(uname+":"+@config["authentication"]["realm"]+":"+p1)
      else
        password = p1
      end
      system "stty echo" 
      @config["accounts"][uname] = password
      save
      puts "Saved!"
    end
    
    def add_worker
      if @config.empty?
        puts "No server configuration is set, so we need to run through the configuration options, first."
        config
      end
      @config["workers"] ||= {}
      name = nil
      confirm = "n"
      until yes?(confirm)
        puts "Enter a worker name:  (Must not contain spaces)"
        name = STDIN.gets.chomp
        unless name.empty? || name =~ /\s/
          puts "You entered: #{name} - Is this correct? (y/N)"
          confirm = STDIN.gets.chomp
        end
      end
      if @config["workers"][name]
        puts "#{name} exists, overwrite? (y/N)"
        unless yes?(STDIN.gets.chomp)
          puts "Exiting."
          exit!
        end
      end
      desc = nil
      confirm = "n"
      until yes?(confirm)
        puts "Enter a description of this worker:"
        desc= STDIN.gets.chomp
        puts "You entered: #{desc} - Is this correct? (y/N)"
        confirm = STDIN.gets.chomp
      end
      cmd = nil
      confirm = "n"
      until yes?(confirm)
        puts "Enter command to launch this worker:"
        cmd= STDIN.gets.chomp
        if cmd.empty?
          puts "Command cannot be empty!"
        else
          puts "You entered: #{cmd} - Is this correct? (y/N)"
          confirm = STDIN.gets.chomp
        end
      end      
      @config["workers"][name] = {"description"=>desc, "command"=>cmd}
      save
      puts "Saved!"
    end    
    
    def save
      file = open(@home+"/taizud.yml", "w")
      file << @config.to_yaml
      file.close
    end
    
    def home_exists?
      !Dir[@home].empty?
    end
    def create_home
      puts "Directory #{@home} does not exist, shall I create it? (y/N)"
      answer = STDIN.gets.chomp
      unless yes?(answer)
        puts "To use a different directory, set the TAIZU_HOME environment variable to your preferred path before running 'taizu init'."
        puts "Exiting."
        exit!
      end
      puts "Creating #{@home}..."
      dirs = @home.split("/")
      path = []
      dirs.each do |dir|
        path << dir
        next if dir.nil? || dir.empty?
        unless Dir[path.join("/")].empty?
          next
        end
        next if d = Dir.mkdir(path.join("/"), 0700)
        puts "Error creating #{path.join("/")}!"
        puts "Exiting!"
        exit!
      end
    end  
    
    def load_config
      if File.exists?(@home + "/taizud.yml")
        @config = YAML.load_file(@home + "/taizud.yml")
      else
        @config = {}
      end  
    end              
  end 
  
  class RemoteWorker
    def initialize
      unless ARGV[1] && ARGV[2]
        puts "Usage: taizu remote {list|start} host:port"
        exit!
      end
      
      case ARGV[1]
      when "list" then list_workers
      when "start" then start_workers
      else
        puts "Usage: taizu remote {list|start} host:port"
        exit!
      end
    end
    
    def list_workers
      host = ARGV[2] + "/workers/"
      host << "#{ARGV[3]}" if ARGV[3]
      host = "http://#{host}" unless host =~ /^http:\/\//
      uri = Addressable::URI.parse(host)
      http = Net::HTTP.new uri.host, uri.port
      request = Net::HTTP::Get.new(uri.request_uri)
      res = http.request request
      until res.code == "200"
        puts "Username:"
        uri.user = STDIN.gets.chomp  
        
        puts "Password:"
        system "stty -echo" 
        uri.password = STDIN.gets.chomp      
        uri.normalize!  
        system "stty echo" 
        #uri.userinfo = "#{user}:#{password}"
        digest_auth = Net::HTTP::DigestAuth.new
        auth = digest_auth.auth_header uri, res['www-authenticate'], request.method  
        uri.userinfo = nil    
        request = Net::HTTP::Get.new(uri.request_uri)
        request.add_field 'Authorization', auth

        res = http.request request 
      end
      puts res.body
    end  
    def start_workers
      host = ARGV[2] + "/workers/"
      unless ARGV[3]
        puts "Usage: taizu remote start host:port worker_name [num_workers]"
        exit!        
      end
      host << ARGV[3]
      host = "http://#{host}" unless host =~ /^http:\/\//
      uri = Addressable::URI.parse(host)
      http = Net::HTTP.new uri.host, uri.port
      request = Net::HTTP::Put.new(uri.request_uri)
      res = http.request request
      until res.code == "200"
        puts "Username:"
        uri.user = STDIN.gets.chomp  
        
        puts "Password:"
        system "stty -echo" 
        uri.password = STDIN.gets.chomp      
        uri.normalize!  
        system "stty echo" 
        #uri.userinfo = "#{user}:#{password}"
        digest_auth = Net::HTTP::DigestAuth.new
        auth = digest_auth.auth_header uri, res['www-authenticate'], request.method  
        uri.userinfo = nil    
        request = Net::HTTP::Put.new(uri.request_uri)
        request.add_field 'Authorization', auth
        request.body = (ARGV[4] || 1)
        res = http.request request 
      end
      puts res.body
    end      
  end 
end

case ARGV[0]
when "init" then Taizu::Environment.new
when "worker" then Taizu::WorkerLauncher.new
when "job" then Taizu::JobLauncher.new
when "server" then Taizu::ServerControl.new
when "remote" then Taizu::RemoteWorker.new
else
  puts "Usage: taizu {init|worker|job|remote|help}"
end


  