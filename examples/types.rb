require_relative '../lib/algeruby'

include Algeruby::ADT

ChargeStatus = Enum["submitted", "pending", "paid", "rejected"]
Currency = Alias[String]
ChargeAmount = Tuple[Integer, Currency]

MetadataObject = Record[
  data: Map[String, String]
]

Charge = Record[
  status: ChargeStatus,
  currency: Currency,
  amount: ChargeAmount,
] + MetadataObject

Error = Record[
  code: Integer,
  message: String,
]

APIResponse = Charge | Error

[ChargeStatus, Currency, ChargeAmount, Charge, Error, APIResponse].each do |t|
  raise "Invalid! #{t}" unless t.valid?
end

puts "Ok."
