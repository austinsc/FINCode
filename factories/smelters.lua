local f0s = component.proxy(component.findComponent("filter f0"))
local machines = component.proxy(component.findComponent("smelter")) 
local primary = component.proxy(component.findComponent("smelter primary"))[1]
local recipe = primary:getRecipe()
local f0itemname = recipe:getIngredients()[1].Type.name

for i, machine in pairs(machines) do
   computer.log(0, "Setting recipe on machine #" .. tostring(i))
   machine:setRecipe(recipe)
end
for i, filter in pairs(f0s) do
   computer.log(0, "Setting filter on f0 #" .. tostring(i))
   filter:setFilterString(f0itemname)
end

