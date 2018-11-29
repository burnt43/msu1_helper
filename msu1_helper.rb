require 'pathname'
require 'optparse'
require 'ostruct'
require 'fileutils'
require 'json'
require './lib/file_convertor'
require './lib/loop_table'
require './lib/argument_parser'

class Msu1Helper
  def initialize(options)
    @options = options
  end

  def execute!
    case @options.output_type
    when 'wav_pcm_s16le'
      @options.input_files.each {|filename|
        FileConvertor.new(filename,{
          destdir: @options.destdir,
        }).convert_to_wav!
      }
    when 'msu1_pcm'
      @options.input_files.each {|filename|
        if loop_bounds = @options.loop_table.loop_bounds_by_filename(filename)
          FileConvertor.new(filename,{
            loop_start_sample_number: loop_bounds[:loop_start],
            loop_end_sample_number:   loop_bounds[:loop_end],
            destdir:                  @options.destdir,
            no_clobber:               @options.no_clobber,
          }).convert_wav_to_msu1_pcm!
        end 
      }
    end
  end
end # Msu1Helper

options = ArgumentParser.parse(ARGV)
Msu1Helper.new(options).execute!
