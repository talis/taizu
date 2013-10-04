module Taizu
  module Client
    attr_reader :gearman_client, :failed_jobs
    
    def self.included(other)
      other.extend(ClassMethods)
    end
    
    def gearman_client
      @gearman_client = Gearman::Client.new(@servers||"localhost:4730") unless @gearman_client        
      @gearman_client
    end
    
    def init_task(task_name, data, opts={}, parent_uniq=nil)
      opts[:uniq] = UUID.generate unless opts[:uniq]
      jt = JobTracker.init(opts[:uniq],nil,task_name)
      jt.queued(parent_uniq)
      args = opts_to_task_args(opts)
      task = case
      when (opts[:background]||opts[:bg]) then Gearman::BackgroundTask.new(task_name, data, args)
      else Gearman::Task.new(task_name, data, args)
      end   
      unless opts[:on_fail]
        task.on_fail do |t|
          jt = JobTracker.init(task.uniq,nil,task_name)
          jt.failed(t)
          puts "Job #{task.uniq} failed\n"              
        end  
      end
      unless opts[:on_exception]
        task.on_exception do |t|
          jt = JobTracker.init(task.uniq,nil,task_name)
          puts "Job #{task.uniq} had an exception\n";
          jt.failed(t)
        end 
      end 
      task           
    end
    
    private
    
    def opts_to_task_args(opts)
      args = {}
      %w{on_complete on_fail on_retry on_exception on_status on_warning on_data
         uniq retry_count priority hash background}.map {|s| s.to_sym }.each do |k|    
        args[k] = opts[k]
      end
      args
    end
    
    module ClassMethods
      def task(task_def, opts={})        
        task_name = case
        when opts[:alias] then opts[:alias]
        else
          (ns, num, method_name) = task_def.to_s.split("_",3)
          method_name
        end        
        meth = Proc.new do |data, *parent_uniq|          
          parent_uniq = parent_uniq.first
          task = init_task(task_def, data, opts, parent_uniq)
          if opts[:on_complete]
            task.on_complete &opts[:on_complete]
          else
            task.on_complete { |t| puts t }
          end
          
          if opts[:on_fail]
            task.on_fail &opts[:on_fail]
          end
          
          if opts[:on_exception]
            task.on_exception &opts[:on_exception]
          end          
          
          ts = Gearman::TaskSet.new(gearman_client)
          ts.add_task(task)
          ts.wait
        end
        define_method task_name.to_sym, meth
      end     
    end    
  end
end