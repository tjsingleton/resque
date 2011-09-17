module Resque
  module Worker::Simple
    extend self


    # Not every platform supports fork. Here we do our magic to
    # determine if yours does.
    def supported?
      true
    end

    def work(worker, interval = 5.0, &block)
      loop do
        break if worker.shutdown?

        if not worker.paused? and job = worker.reserve
          worker.log "got: #{job.inspect}"
          worker.run_hook :before_fork, job
          worker.working_on job

          worker.procline "Processing #{job.queue} since #{Time.now.to_i}"
          worker.perform(job, &block)

          worker.done_working
        else
          break if interval.zero?
          worker.log! "Sleeping for #{interval} seconds"
          worker.procline paused? ? "Paused" : "Waiting for #{worker.queues.join(',')}"
          sleep interval
        end
      end
    end

    # noop
    def kill_child(worker); end
  end
end
