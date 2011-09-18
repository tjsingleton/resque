module Resque
  module  Worker::Forking
    #def very_verbose
    #  true
    #end
    #
    # Not every platform supports fork. Here we do our magic to
    # determine if yours does.
    def self.supported?
      return false if $TESTING

      # IronRuby doesn't support `Kernel.fork` yet
      return false unless Kernel.respond_to?(:fork)

      # test fork
      if Kernel.fork
        Process.wait
      else
        exit!
      end

      true
    rescue NotImplementedError
    end

    def execute_work_strategy(interval, &block)
      loop do
        break if shutdown?

        if not paused? and job = reserve
          log "got: #{job.inspect}"
          run_hook :before_fork, job
          working_on job

          if @child = Kernel.fork
            srand # Reseeding
            procline "Forked #{@child} at #{Time.now.to_i}"
            Process.wait
          else
            procline "Processing #{job.queue} since #{Time.now.to_i}"
            perform(job, &block)
            exit!
          end

          done_working
          @child = nil
        else
          break if interval.zero?
          log! "Sleeping for #{interval} seconds"
          procline paused? ? "Paused" : "Waiting for #{queues.join(',')}"
          sleep interval
        end
      end
    end

    def kill_child
      if @child
        log! "Killing child at #{@child}"
        if system("ps -o pid,state -p #{@child}")
          Process.kill("KILL", @child) rescue nil
        else
          log! "Child #{@child} not found, restarting."
          shutdown
        end
      end
    end
  end
end
