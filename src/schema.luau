type Mapped = {
	boolean: boolean,
	u8: number,
	u16: number,
	string: string,
}

type KeyIdentity<T> = {
	index: keyof<Mapped>,
	optional: true | false,
	read __SCHEMA_IDENTITY: T,
}
type TblIdentity<T> = {
	value: T,
	optional: true | false,
	read __SCHEMA_IDENTITY: T,
}

type function GetIdentity(t: type): type?
	return t:readproperty(types.singleton("__SCHEMA_IDENTITY"))
end

type function FirstInUnion(t: type)
	if t.tag == "union" then
		return t:components()[1]
	end
	return t
end

type function NonNullable(t: type)
	local had_nil = false
	if t.tag == "union" then
		local new_union_t = {}
		for i, v in t:components() do
			if v.tag == "nil" then
				had_nil = true
				continue
			end
			table.insert(new_union_t, v)
		end
		return types.unionof(unpack(new_union_t)), types.singleton(had_nil)
	end
	return t, types.singleton(had_nil)
end

type function __CreateSchemaImpl(t: type)
	local pack = assert(t:parameters().head)

	local function parseTypes(v: type): type
		--assert(v:is("table"), `TYPES CAN ONLY BE TABLES, GOT {v.tag}`)

		local sanitized_type: type = NonNullable(v)
		local identity_result: type? = GetIdentity(sanitized_type)

		assert(identity_result, `INVALID IDENTITY {sanitized_type.tag}`)

		local identity_result, had_nil = NonNullable(identity_result)

		local do_swap = sanitized_type:readproperty(types.singleton("index"))
		local is_table = sanitized_type:readproperty(types.singleton("value"))

		if do_swap then
			local prop = assert(v.readproperty(Mapped, identity_result))
			if had_nil then
				return types.unionof(types.singleton(nil), prop)
			end
			return prop
		elseif is_table then
			local wrap_table = types.newtable()
			for key, value in v:properties() do
				wrap_table:setreadproperty(key, parseTypes(value.read or value.write or types.never))
			end
			return wrap_table
		else
			error(`INVALID TYPE PROVIDED {v.tag}`)
		end
	end

	local inputs = {}
	for i, v in pack do
		table.insert(inputs, parseTypes(v))
	end

	const nt = types.newtable()

	nt:setreadproperty(types.singleton("set"), types.newfunction({ head = inputs }))
	nt:setreadproperty(types.singleton("get"), types.newfunction({}, { head = inputs }))

	return nt
end

type Schema<T...> = __CreateSchemaImpl<(T...) -> ()>

type function KeyReturn(t: type, opt: type): type
	if opt.tag == "singleton" and opt:value() then
		return types.unionof(t, types.singleton(nil))
	else
		return t
	end
end

-- returns:

function val<T, P>(str: T & keyof<Mapped>, optional: ((P & true) | "")?): KeyIdentity<(KeyReturn<T, P>)>
	return {
		index = str,
		optional = (optional or false) :: boolean,
		__SCHEMA_IDENTITY = nil :: never,
	}
end

function struct<T, P>(tbl: T & {}, optional: ((P & true) | "")?): TblIdentity<(KeyReturn<T, P>)>
	return {
		value = tbl,
		optional = (optional or false) :: boolean,
		__SCHEMA_IDENTITY = nil :: never,
	}
end

function schema<T...>(...: T...): Schema<T...>
	return nil :: never
end

return table.freeze({
	new = schema,
	val = val,
	struct = struct,
})
