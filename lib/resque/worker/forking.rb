module Resque
  module Worker::Forking

    extend self

    # Not every platform supports fork. Here we do our magic to
    # determine if yours does.
    def supported?#
      return false if $TESTING

      # IronRuby doesn't support `Kernel.fork` yet
      return false unless Kernel.respond_to?(:fork)

      # test fork
      if fork
        Process.wait
      else
        exit!
      end

      true
    rescue NotImplementedError
    end

    def fork
      Kernel.fork
    end

    def work (worker, interval, &block)
      loop do
        break if worker.shutdown?

        if not worker.paused? and worker.job = reserve
          worker.log "got: #{job.inspect}"
          worker.run_hook :before_fork, job
          worker.working_on job

          if @child = fork
            srand # Reseeding
            worker.procline "Forked #{@child} at #{Time.now.to_i}"
            Process.wait
          else
            worker.procline "Processing #{job.queue} since #{Time.now.to_i}"
            worker.perform(job, &block)
            exit!
          end

          worker.done_working
          @child = nil
        else
          break if interval.zero?
          worker.log! "Sleeping for #{interval} seconds"
          worker.procline paused? ? "Paused" : "Waiting for #{worker.queues.join(',')}"
          sleep interval
        end
      end
    end

    def kill_child(worker)
      if @child
        log! "Killing child at #{@child}"
        if system("ps -o pid,state -p #{@child}")
          Process.kill("KILL", @child) rescue nil
        else
          worker.log! "Child #{@child} not found, restarting."
          worker.shutdown
        end
      end
    end
  end
end
