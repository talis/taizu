require File.dirname(__FILE__) + '/../lib/taizu'

class TextWorker
  include Taizu::Worker
  
  # job_prefix allows us to disambiguate the worker functions.  In this case, all of the functions
  # would appear in Gearman as "textexample_1_{functionName}"
  job_prefix :textexample, 1
  
  # "Abilities" advertise which methods are associated with a particular task name (minus job prefix information)
  # if the value is a Hash, the syntax is "functionName"=>"method_name"
  abilities :reverse, :capitalize, :lowercase, :space_out=>:add_spaces

  # "Ability" methods take two arguments: data and job
  # If you want to return a different value to the JobTracker (for example, something smaller),
  # return an Array with the job response as the first value and the Job Tracker message as the second.
  def reverse(data, job)
    puts "Received job: #{job.handle}:#{job.uniq}"
    puts data.reverse
  end    
  
  def capitalize(data, job)
    puts "Received job: #{job.handle}:#{job.uniq}"
    puts data.upcase
  end    

  def lowercase(data, job)
    puts "Received job: #{job.handle}:#{job.uniq}"
    puts data.downcase
  end 
  
  def add_spaces(data, job) 
    puts "Received job: #{job.handle}:#{job.uniq}"
    puts data.gsub(/(.)/, '\1 ')
  end
end

tw = TextWorker.new
tw.work