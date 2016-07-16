require 'set'

module Algeruby::Serde
  class DeserializationError < StandardError
    def initialize(message, descriptor)
      super(message)
      @descriptor = descriptor
      @message = message
    end

    def inspect
      "Could not deserialize to #{@descriptor.name}: #{message}"
    end
  end

  class Validator
    def initialize(descriptor)
      @descriptor = descriptor
      @deseralizer = Algeruby::Serde.converter_for(descriptor)
    end

    def valid?(ser_value)
      begin
        @deserializer.deserialize(ser_value)
        true
      rescue DeserializationError => de
        false
      end
    end
  end

  def self.converter_for(descriptor)
    converter_class = Converter::TYPE_MAP[descriptor.class]
    if converter_class.nil?
      raise DeserializationError.new(
        "No converter known for type #{descriptor.class}",
        descriptor
      )
    end
    converter_class.new(descriptor)
  end

  def self.deserialize(descriptor, value, **kwargs)
    deserializer = converter_for(descriptor)
    deserializer.deserialize(value, **kwargs)
  end

  module Converter
    class BaseConverter
      def initialize(descriptor)
        @descriptor = descriptor
      end

      def valid?(value)
        @descriptor.include?(value)
      end

      def deserialize(value, **kwargs)
        raise DeserializationError.new("must override in each converter class", @descriptor)
      end
    end

    class IntegerConverter < BaseConverter
      def deserialize(value, **kwargs)
        Integer(value)
      rescue ArgumentError
        raise DeserializationError.new("Can't parse '#{value}' as integer", @descriptor)
      end
    end

    class FloatConverter < BaseConverter
      def deserialize(value, **kwargs)
        Float(value)
      rescue ArgumentError
        raise DeserializationError.new("Can't parse '#{value}' as float", @descriptor)
      end
    end

    class StringConverter < BaseConverter
      def deserialize(value, **kwargs)
        unless value.is_a?(String) || value.is_a?(Symbol)
          raise DeserializationError.new("Non-string value: '#{value}'", @descriptor)
        end

        value
      end
    end

    class NoneConverter < BaseConverter
      def deserialize(value, **kwargs)
        raise DeserializationError.new("Value '#{value}' was not nil") unless value.nil?
        nil
      end
    end

    class AliasConverter < BaseConverter
      def deserialize(value, **kwargs)
        Algeruby::Serde.deserialize(type, value)
      end
    end

    class UnionConverter < BaseConverter
      def deserialize(value, **kwargs)
        value = @descriptor.types.find do |desc|
          Algeruby::Serde.deserialize(desc, value) rescue nil
        end

        if value.nil? && !@descriptor.types.include?(None)
          raise DeserializationError.new(
            "None of #{@descriptor.types} matched value '#{value}'",
            @descriptor
          )
        end

        value
      end
    end

    class EnumConverter < BaseConverter
      def deserialize(value, **kwargs)
        value = @descriptor.values.find do |member|
          if member == value
            value
          elsif Algeruby::ADT.is_valid_type?(member)
            Algeruby::Serde.deserialize(member, value) rescue nil
          end
        end

        if value.nil? && !@descriptor.values.include?(None)
          raise DeserializationError.new(
            "None of #{types} matched value '#{value}'",
            @descriptor
          )
        end

        value
      end
    end

    class TupleConverter < BaseConverter
      def deserialize(value, **kwargs)
        value = []
        @descriptor.types.each_with_index do |desc, index|
          value << Algeruby::Serde.deserialize(desc, value[index])
        end
        value
      end
    end

    class RecordConverter < BaseConverter
      # Accepts an additional `concrete_type` kwarg, which will be treated as
      # a class with a zero-argument constructor to be instantiated and
      # populated with data for this record type via setter methods matching
      # the record's field names. Defaults to simply returning a Hash.
      def deserialize(value, concrete_type: nil)
        if !value.is_a?(Hash)
          raise DeserializationError.new(
            "Can only construct records from hashes",
            @descriptor
          )
        end

        value_keys = Set[*value.keys]
        record_keys = Set[*@descriptor.fields.keys.map {|k| k.to_s}]

        if value_keys != record_keys
          raise DeserializationError.new(
            "Invalid record keys: got #{value_keys.to_a}, expected #{record_keys.to_a}",
            @descriptor
          )
        end

        if concrete_type == nil
          deser_value = {}
          deser_setter = deser_value.method(:[]=)
        else
          deser_value = concrete_type.new
          deser_setter = proc {|k, v| deser_value.send(:"#{k}=", v)}
        end

        value.each do |k, v|
          begin
            deser_setter[k, v]
          rescue DeserializationError => de
            raise DeserializationError.new(
              "Could not load field #{k}: #{de.message}",
              @descriptor
            )
          end
        end

        deser_value
      end
    end

    class ListConverter < BaseConverter
      def deserialize(value, **kwargs)
        value.map {|member| Algeruby::Serde.deserialize(@descriptor, member)}
      end
    end

    class MapConverter < BaseConverter
      def deserialize(value, **kwargs)
        value.inject({}) {|h,p| h[p[0]] = Algeruby::Serde.deserialize(@descriptor, p[1]); h}
      end
    end

    TYPE_MAP = {
      Integer => IntegerConverter,
      Float => FloatConverter,
      String => StringConverter,
      Algeruby::ADT::None => NoneConverter,
      Algeruby::ADT::Alias => AliasConverter,
      Algeruby::ADT::Union => UnionConverter,
      Algeruby::ADT::Enum => EnumConverter,
      Algeruby::ADT::Tuple => TupleConverter,
      Algeruby::ADT::Record => RecordConverter,
      Algeruby::ADT::List => ListConverter,
      Algeruby::ADT::Map => MapConverter,
    }
  end
end
