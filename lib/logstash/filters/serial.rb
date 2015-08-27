# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "logstash/timestamp"
require "net/http"
require 'net/https'
require "uri"
require "json"

class LogStash::Filters::Serial < LogStash::Filters::Base

    config_name "serial"

    # The configuration for the SERIAL filter:
    # [source,ruby]
    #     source => source_field
    #
    # For example, if you have SERIAL data in the `message` field:
    # [source,ruby]
    #     filter {
    #       json {
    #         source => "message"
    #       }
    #     }
    #
    # The above would parse the json from the `message` field
    config :source, :validate => :string, :required => true

    # Define the target field for placing the parsed data. If this setting is
    # omitted, the SERIAL data will be stored at the root (top level) of the event.
    #
    # For example, if you want the data to be put in the `doc` field:
    # [source,ruby]
    #     filter {
    #       json {
    #         target => "doc"
    #       }
    #     }
    #
    # SERIAL in the value of the `source` field will be expanded into a
    # data structure in the `target` field.
    #
    # NOTE: if the `target` field already exists, it will be overwritten!
    config :target, :validate => :string

    public
    def register
        # Nothing to do here
    end # def register

    public
    def filter(event)
        return unless filter?(event)

        @logger.debug("Running serial filter", :event => event)

        return unless event.include?(@source)

        # TODO(colin) this field merging stuff below should be handled in Event.

        source = event[@source]

        begin

            uri = URI.parse("http://localhost:8080/service.php")
            post_data = {
                :type => 'magento-report',
                :data => source
            }
            res = Net::HTTP.post_form(uri, post_data)
            parsed = LogStash::Json.load(res.body)  # response from api

            #      pasred = PhpSerialization.unserializer.run(source)
            #     parsed = PHP.unserialize(source)
            #      parsed = LogStash::Json.load(source)
            # If your parsed SERIAL is an array, we can't merge, so you must specify a
            # destination to store the SERIAL, so you will get an exception about
            if parsed.kind_of?(Array) && @target.nil?
                raise('Parsed Serial arrays must have a destination in the configuration')
            elsif @target.nil?
                event.to_hash.merge! parsed
            else
                event[@target] = parsed
            end

            # If no target, we target the root of the event object. This can allow
            # you to overwrite @timestamp and this will typically happen for serial
            # LogStash Event deserialized here.
            if !@target && event.timestamp.is_a?(String)
                event.timestamp = LogStash::Timestamp.parse_iso8601(event.timestamp)
            end

            filter_matched(event)
        rescue => e
            tag = "_serialparsefailure"
            event["tags"] ||= []
            event["tags"] << tag unless event["tags"].include?(tag)
            @logger.warn("Trouble parsing serial", :source => @source,
                         :raw => event[@source], :exception => e)
            return
        end

        @logger.debug("Event after serial filter", :event => event)

    end # def filter

end # class LogStash::Filters::Serial
