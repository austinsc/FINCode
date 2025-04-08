local filters = {
   component.proxy(component.findComponent("filter f0")), 
   component.proxy(component.findComponent("filter f1")), 
   component.proxy(component.findComponent("filter f2")),
   component.proxy(component.findComponent("filter f3"))
}
local machines = component.proxy(component.findComponent("mfg")) 
local primary = component.proxy(component.findComponent("mfg primary"))[1]
local recipe = primary:getRecipe()
local ingredients = recipe:getIngredients()

for i, machine in pairs(machines) do
   computer.log(0, "Setting recipe on machine #" .. tostring(i))
   machine:setRecipe(recipe)
end

for f, item in ingredients do
   for i, filter in pairs(filters[f]) do
      computer.log(0, "Setting filter on f" .. tostring(f - 1)" #" .. tostring(i))
      filter:setFilterString(item.Type.name)
   end
end

