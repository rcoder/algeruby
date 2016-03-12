require_relative 'types'

ChargeStatus = Enum["submitted", "pending", "paid", "rejected"]
Currency = Alias[String]
ChargeAmount = Tuple[Fixnum, Currency]

MetadataObject = Record[
  data: Map[String, String]
]

Charge = Record[
  status: ChargeStatus,
  currency: Currency,
  amount: ChargeAmount,
] + MetadataObject

Error = Record[
  code: Fixnum,
  message: String,
]

APIResponse = Charge | Error

[ChargeStatus, Currency, ChargeAmount, Charge, Error, APIResponse].each do |t|
  puts "Invalid! #{t}" unless t.valid?
end
