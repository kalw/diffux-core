require 'phantomjs'
require 'json'
%w(base gutter before after overlayed).each do |type|
  require_relative "snapshot_comparison_image/#{type}"
end
module Diffux
  # Snapshotter is responsible for delegating to PhantomJS to take the snapshot
  # for a given URL and viewoprt, and then saving that snapshot to a file and
  # storing any metadata on the Snapshot object.
  class Snapshotter
    SCRIPT_PATH = File.join(File.dirname(__FILE__),
                            'script/take-snapshot.js').to_s

    # @param url [String} the URL to snapshot
    # @param viewport_width [Integer] the width of the screen used when
    #   snapshotting
    # @param outfile [File] where to store the snapshot PNG.
    # @param user_agent [String] an optional useragent string to used when
    #   requesting the page.
    # @param crop_selector [String] an optional string containing a CSS
    #   selector. If this is present, and the page contains something matching
    #   it, the resulting snapshot image will only contain that element. If the
    #   page contains multiple elements mathing the selector, only the first
    #   element will be used.
    def initialize(url:     raise, viewport_width: raise,
                   outfile: raise, user_agent: nil,
                   crop_selector: nil)
      @viewport_width = viewport_width
      @crop_selector  = crop_selector
      @user_agent     = user_agent
      @outfile        = outfile
      @url            = url
    end

    # Takes a snapshot of the URL and saves it in the outfile as a PNG image.
    #
    # @return [Hash] a hash containing the following keys:
    #   title [String] the <title> of the page being snapshotted
    #   log   [String] a log of events happened during the snapshotting process
    def take_snapshot!
      result = {}
      opts = {
        address: @url,
        outfile: @outfile,
        cropSelector: @crop_selector,
        viewportSize: {
          width:  @viewport_width,
          height: @viewport_width,
        },
      }
      opts[:userAgent] = @user_agent if @user_agent

      run_phantomjs(opts) do |line|
        begin
          result = JSON.parse line, symbolize_names: true
        rescue JSON::ParserError
          # We only expect a single line of JSON to be output by our snapshot
          # script. If something else is happening, it is likely a JavaScript
          # error on the page and we should just forget about it and move on
          # with our lives.
        end
      end
      result
    end

    private

    def run_phantomjs(options)
      Phantomjs.run('--ignore-ssl-errors=true',
                    SCRIPT_PATH, options.to_json) do |line|
        yield line
      end
    end
  end
end
