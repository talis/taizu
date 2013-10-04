# These are changes to gearman-ruby to allow workers to pick up uniq jobs
include Gearman
class Gearman::Worker
  attr_reader :grab_job_cmd
  # We have exposed the handle attribute as well as added an optional uniq arg/attribute
  class Job
    attr_reader :handle, :uniq
    def initialize(sock, handle, uniq=nil)
      @socket = sock
      @handle = handle
      @uniq = uniq
    end

  end
  
  def grab_job_uniq?
    @grab_job == :grab_job_uniq
  end
  
  def grab_job_uniq(b=true)
    if b
      @grab_job_cmd = :grab_job_uniq
    else
      @grab_job_cmd = :grab_job
    end
  end
  
  def grab_job_cmd
    grab_job_uniq unless @grab_job_cmd
    @grab_job_cmd
  end
  
  def work
    req = Util.pack_request(grab_job_cmd)
    loop do
      @status = :preparing
      bad_servers = []
      # We iterate through the servers in sorted order to make testing
      # easier.
      servers = nil
      @servers_mutex.synchronize { servers = @sockets.keys.sort }
      servers.each do |hostport|
        Util.logger.debug "GearmanRuby: Sending grab_job to #{hostport}"
        sock = @sockets[hostport]
        Util.send_request(sock, req)

        # Now that we've sent grab_job, we need to keep reading packets
        # until we see a no_job or job_assign response (there may be a noop
        # waiting for us in response to a previous pre_sleep).
        loop do
          begin
            type, data = Util.read_response(sock, @network_timeout_sec)
            case type
            when :no_job
              Util.logger.debug "GearmanRuby: Got no_job from #{hostport}"
              break
            when :job_assign
              @status = :working
              return worker_enabled if handle_job_assign(data, sock, hostport)
              break
            when :job_assign_uniq
              @status = :working
              return worker_enabled if handle_job_assign_uniq(data, sock, hostport)
              break              
            else
              Util.logger.debug "GearmanRuby: Got #{type.to_s} from #{hostport}"
            end
          rescue Exception
            Util.logger.debug "GearmanRuby: Server #{hostport} timed out or lost connection (#{$!.inspect}); marking bad"
            bad_servers << hostport
            break
          end
        end
      end

      @servers_mutex.synchronize do
        bad_servers.each do |hostport|
          @sockets[hostport].close if @sockets[hostport]
          @bad_servers << hostport if @sockets[hostport]
          @sockets.delete(hostport)
        end
      end

      Util.logger.debug "GearmanRuby: Sending pre_sleep and going to sleep for #{@reconnect_sec} sec"
      @servers_mutex.synchronize do
        @sockets.values.each do |sock|
          Util.send_request(sock, Util.pack_request(:pre_sleep))
        end
      end

      return false unless worker_enabled
      @status = :waiting

      # FIXME: We could optimize things the next time through the 'each' by
      # sending the first grab_job to one of the servers that had a socket
      # with data in it.  Not bothering with it for now.
      IO::select(@sockets.values, nil, nil, @reconnect_sec)
    end
  end  
  def handle_job_assign_uniq(data, sock, hostport)
    handle, func, uniq, data = data.split("\0", 4)
    if not func
      Util.logger.error "GearmanRuby: Ignoring job_assign_uniq with no function from #{hostport}"
      return false
    end

    Util.logger.error "GearmanRuby: Got job_assign_uniq with handle #{handle} and #{data.size} byte(s) " +
      "from #{hostport}"

    ability = @abilities[func]
    if not ability
      Util.logger.error "Ignoring job_assign_uniq for unsupported func #{func} " +
        "with handle #{handle} from #{hostport}"
      Util.send_request(sock, Util.pack_request(:work_fail, handle))
      return false
    end

    exception = nil
    begin
      ret = ability.run(data, Job.new(sock, handle, uniq))
    rescue Exception => e
      exception = e
      Util.logger.debug "GearmanRuby: Exception: #{e}\n#{e.backtrace.join("\n")}\n"
    end

    cmd = if ret && exception.nil?
      Util.logger.debug "GearmanRuby: Sending work_complete for #{handle} with #{ret.to_s.size} byte(s) " +
        "to #{hostport}"
      [ Util.pack_request(:work_complete, "#{handle}\0#{ret.to_s}") ]
    elsif exception.nil?
      Util.logger.debug "GearmanRuby: Sending work_fail for #{handle} to #{hostport}"
      [ Util.pack_request(:work_fail, handle) ]
    elsif exception
      Util.logger.debug "GearmanRuby: Sending work_exception for #{handle} to #{hostport}"
      [ Util.pack_request(:work_exception, "#{handle}\0#{exception.message}") ]
    end

    cmd.each {|p| Util.send_request(sock, p) }
    
    # There are cases where we might want to run something after the worker
    # successfully completes the ability in question and sends its results
    if ret && exception.nil?
      after_ability = @after_abilities[func]
      if after_ability
        Util.logger.debug "Running after ability for #{func}..."
        begin
          after_ability.run(ret, data)
        rescue Exception => e
          Util.logger.debug "GearmanRuby: Exception: #{e}\n#{e.backtrace.join("\n")}\n"
          nil
        end
      end
    end    
    true
  end      
end