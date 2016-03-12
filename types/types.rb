class TypeConstructor
  def self.[](*args)
    inst = new(*args)
    raise ArgumentError.new("invalid type constructor") unless inst.valid?
    inst
  end

  def is_type?(obj)
    obj.is_a?(Class) | obj.is_a?(TypeConstructor)
  end

  def |(other)
    Union[self, other]
  end
end

class Alias < TypeConstructor
  def initialize(type)
    @type = type
  end

  def valid?
    @type.is_a?(Class)
  end

  def include?(value)
    value.is_a?(@type)
  end
end

class Union < TypeConstructor
  def initialize(*types)
    @types = types
  end

  def valid?
    @types.all? {|t| is_type?(t)}
  end

  def include?(value)
    @types.any? {|t| value.is_a?(t)}
  end
end

class Enum < TypeConstructor
  def initialize(*values)
    @values = values
  end

  def valid?
    @values.map(&:class).uniq.size == 1
  end

  def include?(value)
    @values.include?(value)
  end
end

class Tuple < TypeConstructor
  def initialize(*types)
    @types = types
  end

  def valid?
    @types.all? {|t| is_type?(t)}
  end

  def include?(value)
    value.is_a?(Enumerable) && @types.zip(value).all? {|v,t| v.is_a?(t)}
  end
end

class Record < TypeConstructor
  def initialize(**fields)
    @fields = fields
  end

  def valid?
    @fields.values.all? {|ft| is_type?(ft)}
  end

  def include?(value)
    value.is_a?(Hash) &&
    value.keys == @fields.keys &&
    value.values.zip(@fields.values).all? {|v,t| v.is_a?(t)}
  end

  def +(other)
    merged_fields = {}

    (other.fields.keys + @fields.keys).uniq.each do |fk|
      my_type = @fields[fk]
      other_type = other.fields[fk]
      if my_type.nil?
        merged_fields[fk] = other_type
      elsif other_type.nil?
        merged_fields[fk] = my_type
      # where a field exists in both records, take the most specific subtype
      elsif my_type < other_type
        merged_fields[fk] = my_type
      elsif other_type <= my_type
        merged_fields[fk] = other_type
      else
        # no ordering, so no relation between the types
        raise RuntimeError.new("type mismatch in Record.+: #{fk}")
      end
    end

    Record.new(**merged_fields)
  end

  protected

  attr_reader :fields
end

class List < TypeConstructor
  def initialize(type)
    @type = type
  end

  def valid?
    is_type?(@type)
  end

  def include?(value)
    value.is_a?(Enumerable) && value.all? {|v| v.is_a?(@type)}
  end
end

class Map < TypeConstructor
  def initialize(key_type, val_type)
    @key_type = key_type
    @val_type = val_type
  end

  def valid?
    is_type?(@key_type) && is_type?(@val_type)
  end

  def include?(value)
    value.keys.all? {|k| k.is_a?(@key_type)} &&
    value.values.all? {|v| v.is_a?(@val_type)}
  end
end
