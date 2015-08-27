require "logstash/devutils/rspec/spec_helper"
require "logstash/timestamp"
require "logstash/filters/serial"

describe LogStash::Filters::Serial do

  describe "parse message into the event" do
    config <<-CONFIG
      filter {
        serial {
          # Parse message as SERIAL
          source => "message"
          target => "report"
        }
      }
    CONFIG

    fi = File.open('/tmp/10000000001', "rb");
    sample fi.read do
      p subject["report"]
#     insist { subject["foo"] } == "bar"
    end
  end
end
