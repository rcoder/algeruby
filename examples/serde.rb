require_relative '../lib/algeruby'

# Mock API schema
include Algeruby::ADT

Error = Record[
  code: Integer,
  message: String
]

BasicValue = T[Integer] | Float | String

Success = Record[
  object: String,
  data: Map[String, BasicValue]
]

Result = Error | Success

LaxResult = Error | Success | Anything

TwoBits = Tuple[Bool, Bool]

error_data = {
  "code" => 1,
  "message" => "invalid request"
}

success_data = {
  "object" => "ack",
  "data" => {
    "a" => "ok",
    "b" => 1,
    "c" => 3.5
  }
}

invalid_data = {
  "bad" => "wolf"
}

Algeruby::Serde.deserialize(Result, error_data)
print "."

Algeruby::Serde.deserialize(Result, success_data)
print "."

Algeruby::Serde.deserialize(LaxResult, success_data)
print "."

Algeruby::Serde.deserialize(TwoBits, [true, false])
print "."

begin
  p Algeruby::Serde.deserialize(Result, invalid_data)
  puts "Nope!!"
  exit 1
rescue Algeruby::Serde::DeserializationError
  print "."
end

puts "Ok."
