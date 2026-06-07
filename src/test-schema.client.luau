local schema = require(script.Parent.schema)
local new = schema.new
local val = schema.val
local struct = schema.struct

const res = val("boolean", true)

const test_schema = new(res)
test_schema.set()
