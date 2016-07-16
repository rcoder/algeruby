module Algeruby::ADT
  PRIMITIVE_TYPES = [
    Integer,
    Float,
    String
  ]

  class TypeDescriptor
    def initialize
      raise RuntimeError.new("cannot instantiate base constructor class")
    end

    def self.[](*args)
      inst = new(*args)
      raise ArgumentError.new("invalid type constructor") unless inst.valid?
      inst
    end

    def |(other)
      Union[self, other]
    end
  end

  def self.valid_type?(obj)
    obj.is_a?(TypeDescriptor) | (obj.is_a?(Class) && PRIMITIVE_TYPES.include?(obj))
  end

  class None < TypeDescriptor
    def initialize; end

    def valid?
      true
    end

    def include?(value)
      value.nil?
    end
  end

  class Alias < TypeDescriptor
    attr_reader :type

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

  class Union < TypeDescriptor
    attr_reader :types

    def initialize(*types)
      @types = types.freeze
    end

    def valid?
      @types.all? {|t| Algeruby::ADT.valid_type?(t)}
    end

    def include?(value)
      @types.any? {|t| value.is_a?(t)}
    end
  end

  class Enum < TypeDescriptor
    attr_reader :values

    def initialize(*values)
      @values = values.freeze
    end

    def valid?
      @values.map(&:class).uniq.size == 1
    end

    def include?(value)
      @values.include?(value)
    end
  end

  class Tuple < TypeDescriptor
    attr_reader :types

    def initialize(*types)
      @types = types.freeze
    end

    def valid?
      @types.all? {|t| Algeruby::ADT.valid_type?(t)}
    end

    def include?(value)
      value.is_a?(Enumerable) && @types.zip(value).all? {|v,t| v.is_a?(t)}
    end
  end

  class Record < TypeDescriptor
    attr_reader :fields

    def initialize(**fields)
      @fields = fields.freeze
    end

    def valid?
      @fields.values.all? {|ft| Algeruby::ADT.valid_type?(ft)}
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
  end

  class List < TypeDescriptor
    attr_reader :type

    def initialize(type)
      @type = type
    end

    def valid?
      Algeruby::ADT.valid_type?(@type)
    end

    def include?(value)
      value.is_a?(Enumerable) && value.all? {|v| v.is_a?(@type)}
    end
  end

  class Map < TypeDescriptor
    attr_reader :key_type, :val_type

    def initialize(key_type, val_type)
      @key_type = key_type
      @val_type = val_type
    end

    def valid?
      Algeruby::ADT.valid_type?(@key_type) && Algeruby::ADT.valid_type?(@val_type)
    end

    def include?(value)
      value.keys.all? {|k| k.is_a?(@key_type)} &&
      value.values.all? {|v| v.is_a?(@val_type)}
    end
  end
end
