module ModernTimes
  module Batch
    module JobStatus

      # Note: String max is set to 8 as defined in the schema.rb file

      # Job has been acquired but is not yet running
      INITED   = 'Inited'

      # Job is currently running
      RUNNING  = 'Running'

      # Job has paused because the worker has been commanded to stop
      PAUSED  = 'Paused'

      # A client has canceled the job
      CANCELED = 'Canceled'

      # The job has been aborted due to threshold constraints (too many record failures)
      ABORTED  = 'Aborted'

      # The job has finished
      FINISHED = 'Finished'

      STATUSES = [INITED, RUNNING, PAUSED, CANCELED, ABORTED, FINISHED].freeze

    end
  end
end
