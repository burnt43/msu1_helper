class LoopTable
  def initialize(filename)
    @data = Hash.new

    File.open(filename, 'r') {|f|
      f.each_line {|line|
        values     = line.strip.split(',')
        filename   = values[0]
        loop_start = values[1].to_i
        loop_end   = values[2].to_i

        @data[filename] = {
          loop_start: loop_start,
          loop_end:   loop_end,
        }
      }
    }
  end

  def has_filename?(filename)
    @data.has_key?(key_from_filename(filename))
  end

  def loop_bounds_by_filename(filename)
    @data[key_from_filename(filename)]
  end

  private

  def key_from_filename(filename)
    Pathname.new(filename).basename.to_s
  end
end # LoopTable
