class GenerateSlidesJob < ActiveJob::Base
  queue_as :default

  def perform(record)
    record.generate_slides
  end
end
