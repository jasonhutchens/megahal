require 'byebug'
require 'sooth'

class MegaHAL
  # Create a new MegaHAL instance, loading the :default personality.
  def initialize
    @fore = Sooth::Predictor.new(0)
    @back = Sooth::Predictor.new(0)
    @case = Sooth::Predictor.new(0)
    @punc = Sooth::Predictor.new(0)
    become(:default)
  end

  def inspect
    to_s
  end

  # Wipe MegaHAL's brain. Note that this wipes the personality too, allowing you
  # to begin from a truly blank slate.
  def clear
#   @fore.clear    
#   @back.clear    
#   @case.clear    
#   @punc.clear    
    @dictionary = { "<error>" => 0, "<blank>" => 1 }
    nil
  end

  def self.add_personality(name, data)
    @@personalities ||= {}
    @@personalities[name.to_sym] = data.each_line.to_a
    nil
  end

  # Returns an array of MegaHAL personalities.
  #
  # @return [Array] A list of symbols representing the available personalities.
  def self.list
    @@personalities ||= {}
    @@personalities.keys
  end

  # Loads the specified personality. Will raise an exception if the personality
  # parameter isn't one of those returned by #list. Note that this will clear
  # MegaHAL's brain first.
  #
  # @param [Symbol] personality The personality to be loaded.
  def become(personality=:default)
    clear
    _train(@@personalities[:default])
  end

  # Generate a reply to the user's input. If the learn parameter is set to true,
  # MegaHAL will also learn from what the user said.
  # 
  # @param [String] input A string that represents the user's input.
  # @param [Bool] learn Whether or not MegaHAL should learn the input.
  # @param [String] error The default reply, which will be used when no
  #                       suitable reply can be formed.
  #
  # @return [String] MegaHAL's reply to the user's input, or the error
  #                  string if no reply could be formed.
  def reply(input, learn=true, error="I don't know enough to answer you yet!")
    puncs, norms, words = _decompose(input.strip)

    _learn(puncs, norms, words) if learn

    norms.clear
    words.clear
    puncs.clear

    context = [1, 1]
    return error if @fore.count(context) == 0
    loop do
      limit = rand(@fore.count(context)) + 1
      norm = @fore.select(context, limit)
      raise if norm == 0
      break if norm == 1
      norms << norm
      context << norm
      context.shift
    end

    context = [1, 1]
    norms.each do |norm|
      context[1] = norm
      limit = rand(@case.count(context)) + 1
      words << @case.select(context, limit)  
      raise if words.last == 0
      context[0] = words.last
    end

    context = [1, 1]
    (words + [1]).each do |word|
      context << word
      context.shift
      limit = rand(@punc.count(context)) + 1
      puncs << @punc.select(context, limit)  
      raise if puncs.last == 0
    end

    _rewrite(puncs, norms, words)
  end

  # Save MegaHAL's brain to the specified binary file.
  #
  # @param [String] filename The brain file to be saved.
  def save(filename)
    raise
  end

  # Load a brain that has previously been saved.
  #
  # @param [String] filename The brain file to be loaded.
  def load(filename)
    raise
  end

  # Merge a brain that has previously been saved. This is similar to #load, but
  # doesn't clear MegaHAL's brain first. This makes it easy to merge several
  # brain files together.
  #
  # @param [String] filename The brain file to be merged.
  def merge(filename)
    raise
  end

  # Train MegaHAL with the contents of the specified file, which should be plain
  # text with one sentence per line.  Note that it takes MegaHAL about one
  # second to process about 500 lines, so large files may cause the process to
  # block for a while. Lines that are too long will be skipped.
  #
  # @param [String] filename The text file to be used for training.
  def train(filename)
    _train(File.read(filename).each_line.to_a)
  end

  private

  def _train(data)
    data.map!(&:strip!)
    data.each do |line|
      puncs, norms, words = _decompose(line)
      _learn(puncs, norms, words)
    end
    nil
  end

  def _learn(puncs, norms, words)
    return [] if words.length == 0

    context = [1, 1]
    norms.each do |norm|
      @fore.observe(context, norm)  
      context << norm
      context.shift
    end
    @fore.observe(context, 1)

    context = [1, 1]
    norms.reverse.each do |norm|
      @back.observe(context, norm)  
      context << norm
      context.shift
    end
    @back.observe(context, 1)

    context = [1, 1]
    words.zip(norms).each do |word, norm|
      context[1] = norm
      @case.observe(context, word)  
      context[0] = word
    end

    context = [1, 1]
    puncs.zip(words + [1]).each do |punc, word|
      context << word
      context.shift
      @punc.observe(context, punc)  
    end

    norms
  end

  def _decompose(line, maximum_length=1024)
    line = "" if line.length > maximum_length
    puncs, words = _segment(line)
    norms = words.map(&:upcase)
    puncs.map! { |punc| @dictionary[punc] ||= @dictionary.length }
    norms.map! { |norm| @dictionary[norm] ||= @dictionary.length }
    words.map! { |word| @dictionary[word] ||= @dictionary.length }
    [puncs, norms, words]
  end

  def _segment(line)
    sequence = line.split(/([[:word:]]+)/)
    sequence << "" if sequence.last =~ /[[:word:]]+/
    sequence.unshift('') if sequence.first =~ /[[:word:]]+/
    while index = sequence[1..-2].index { |item| item =~ /^['-]$/ } do
      sequence[index+1] = sequence[index, 3].join
      sequence[index] = nil
      sequence[index+2] = nil
      sequence.compact!
    end
    sequence.partition.with_index { |symbol, index| index.even? }
  end

  def _rewrite(puncs, norms, words)
    decode = Hash[@dictionary.to_a.map(&:reverse)]
    puncs.zip(words).flatten.map { |word| decode[word] }.join
  end
end
