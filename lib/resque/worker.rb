module Resque
  # A Resque Worker processes jobs. On platforms that support fork(2),
  # the worker will fork off a child to process each job. This ensures
  # a clean slate when beginning the next job and cuts down on gradual
  # memory growth as well as low level failures.
  #
  # It also ensures workers are always listening to signals from you,
  # their master, and can react accordingly.
  class Worker
    extend Resque::Helpers

    # Returns an array of all worker objects.
    def self.all
      Array(redis.smembers(:workers)).map { |id| find(id) }.compact
    end

    # Returns an array of all worker objects currently processing
    # jobs.
    def self.working
      names = all
      return [] unless names.any?

      names.map! { |name| "worker:#{name}" }

      reportedly_working = redis.mapped_mget(*names).reject do |key, value|
        value.nil? || value.empty?
      end
      reportedly_working.keys.map do |key|
        find key.sub("worker:", '')
      end.compact
    end

    # Returns a single worker object. Accepts a string id.
    def self.find(worker_id)
      if exists? worker_id
        queues = worker_id.split(':')[-1].split(',')
        worker = new(*queues)
        worker.to_s = worker_id
        worker
      else
        nil
      end
    end

    # Alias of `find`
    def self.attach(worker_id)
      find(worker_id)

    end

    # Given a string worker id, return a boolean indicating whether the
    # worker exists
    def self.exists?(worker_id)
      redis.sismember(:workers, worker_id)
    end

    def self.new(*queues)
      Resque.worker_strategy.new(*queues)
    end
  end
end
