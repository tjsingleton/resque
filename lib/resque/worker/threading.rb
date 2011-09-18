module Resque
  module Worker::Threading
    def work_strategy(interval = 5.0, &block)
     threads = []
     thread_count.times do |idx|
       threads << Thread.new do
         Thread.current[:resque_thread_idx] = idx
         log! "Starting thread #{idx}"
         loop do
           job = nil
           begin
             break if shutdown?

             if not paused? and job = reserve
               log "got: #{job.inspect}"
               run_hook :before_fork, job
               working_on job

               procline "Processing #{job.queue} since #{Time.now.to_i}"
               perform(job, &block)

               done_working
             else
               break if interval.zero?
               log! "Sleeping for #{interval} seconds"
               procline paused? ? "Paused" : "Waiting for #{@queues.join(',')}"
               sleep interval
             end
           rescue Exception => ex
             p [ex.class.name, ex.message]
             puts ex.backtrace.join("\n")
             job.fail(ex) if job
           end
         end
       end
     end

     while !shutdown? do
       sleep 1
     end

     log "Shutting down, main thread waiting up to #{exit_timeout} sec for workers to finish..."
     # wait up to 30 seconds for worker threads to exit
     count = 0
     while threads.any?(&:alive?) && count < exit_timeout
       sleep 1
       count += 1
     end
     log 'Threads shutdown, exiting...'
    end

    def thread_count
      (ENV['RESQUE_THREADS'] || 10).to_i
    end

    def exit_timeout
      (ENV['RESQUE_EXIT_TIMEOUT'] || 30).to_i
    end

    def tid
      "T#{Thread.current[:resque_thread_idx] || 'main'}"
    end

    def uniq_id
      "#{$$}#{tid}"
    end
  end
end



