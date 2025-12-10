-- Exported Types
export type Entity<T> = {
	Model: Model?,
	UUID: string,
	Tags: { string }
} & T

-- Register
local Register = {}
Register.Data = {} :: { Entity<any> }

function Register.RegisterData<T>(entity: Entity<T>): Entity<T>
	table.insert(Register.Data, entity)
	return entity
end

function Register.UnregisterData<T>(entity: Entity<T>): Entity<T>
	local index = table.find(Register.Data, entity)
	if index then
		table.remove(Register.Data, index)
	end
	return entity
end

function Register.FetchDataByUUID(uuid: string): Entity<any>?
	for _, data in ipairs(Register.Data) do
		if data.UUID == uuid then
			return data :: Entity<any>
		end
	end
	return nil
end

function Register.FetchDataByTag(tag: string): { Entity<any> }
	local results: { Entity<any> } = {}
	for _, data in ipairs(Register.Data) do
		if table.find(data.Tags, tag) then
			table.insert(results, data :: Entity<any>)
		end
	end
	return results
end

function Register.FetchDataByModel(model: Model): Entity<any>?
	for _, data in ipairs(Register.Data) do
		if data.Model == model then
			return data :: Entity<any>
		end
	end
	return nil
end

function Register.FetchDataByDescendant(instance: Instance): Entity<any>?
	for _, data in ipairs(Register.Data) do
		if data.Model and instance:IsDescendantOf(data.Model) then
			return data :: Entity<any>
		end
	end
	return nil
end

return Register
