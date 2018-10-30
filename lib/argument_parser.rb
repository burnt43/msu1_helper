class ArgumentParser
  OUTPUT_TYPES = %w(wav_pcm_s16le msu1_pcm)

  def self.parse(args)
    options = OpenStruct.new
    options.input_files = nil
    options.output_type = nil
    options.loop_start  = nil
    options.loop_end    = nil
    options.loop_table  = nil
    options.destdir     = nil

    option_parser = OptionParser.new {|opts|
      opts.on("-i", "--input-files=INPUT_FILES", "input file or glob") {|input|
        options.input_files = Dir[input]
      }

      opts.on("-t", "--output-type=OUTPUT_TYPE", "type to convert audio to (#{OUTPUT_TYPES.join(', ')})") {|output_type|
        options.output_type = output_type
      }

      opts.on("-s", "--loop-start=LOOP_START", "sample number of where the loop should start") {|loop_start|
        options.loop_start = loop_start
      }

      opts.on("-e", "--loop-end=LOOP_END", "sample number of where the loop should end") {|loop_end|
        options.loop_end = loop_end
      }

      opts.on("-l", "--loop-table=LOOP_TABLE", "loop table filename") {|loop_table_filename|
        options.loop_table = File.exists?(loop_table_filename) ? LoopTable.new(loop_table_filename) : nil
      }

      opts.on("-d", "--destdir=DESTDIR", "write converted files to this directory") {|destdir|
        options.destdir = destdir
      }

      opts.on_tail("-h", "--help", "show this message") do
        puts opts
        exit
      end
    }

    option_parser.parse!(args)

    validate_options(options)
    options
  end

  private

  def self.validate_options(options)
    unless options.input_files
      print_error("no input was given. please specify using -i or --input-files.")
    end

    unless options.output_type
      print_error("no output_type was given. please specify using -t or --output-type")
    end

    # no input files
    if options.input_files.empty?
      print_error("could not find any input files.")
    # 1 input file
    elsif options.input_files.length == 1
      if options.output_type == 'msu1_pcm'
        if (options.loop_start.nil? || options.loop_end.nil?)
          print_error("you want to convert a single file to msu1_pcm, but have not given a LOOP START or LOOP END. please specify using -s or --loop-start and -e or --loop-end.")
        end
      end
    # multiple input files
    else
      if options.output_type == 'msu1_pcm'
        if options.loop_table.nil?
          print_error("you want you convert many files to msu1_pcm, but you have not provided a loop_table file. please specift using -l or --loop-table")
        else
          options.input_files
            .reject{|filename| options.loop_table.has_filename?(filename)}
            .each{|filename| print_warning("#{filename} is not in the loop table. it will be ignored and not be converted.")}
        end
      end
    end
  end

  def self.print_warning(warning_message)
    puts "[\033[0;33mWARNING\033[0;0m] - #{warning_message}"
  end

  def self.print_error(error_message)
    puts "[\033[0;31mERROR\033[0;0m] - #{error_message}"
    exit 1
  end
end # ArgumentParser
