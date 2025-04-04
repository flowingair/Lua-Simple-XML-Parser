local xmlSimple = {}

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--
-- xml.lua - XML parser for use with the Corona SDK.
--
-- version: 1.2
--
-- CHANGELOG:
--
-- 1.2 - Created new structure for returned table
-- 1.1 - Fixed base directory issue with the loadFile() function.
--
-- NOTE: This is a modified version of Alexander Makeev's Lua-only XML parser
-- found here: http://lua-users.org/wiki/LuaXml
--
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
function xmlSimple.newParser()

    XmlParser = {};

    -- function XmlParser:ToXmlString(value)
    --     value = string.gsub(value, "&", "&amp;"); -- '&' -> "&amp;"
    --     value = string.gsub(value, "<", "&lt;"); -- '<' -> "&lt;"
    --     value = string.gsub(value, ">", "&gt;"); -- '>' -> "&gt;"
    --     value = string.gsub(value, "\"", "&quot;"); -- '"' -> "&quot;"
    --     value = string.gsub(value, "([^%w%&%;%p%\t% ])", function(c)
    --         return string.format("&#x%X;", string.byte(c))
    --     end);
    --     return value;
    -- end

    function XmlParser:FromXmlString(value)
        local utf8bits = {{0x7FF, {192, 32}, {128, 64}}, {0xFFFF, {224, 16}, {128, 64}, {128, 64}},
                          {0x1FFFFF, {240, 8}, {128, 64}, {128, 64}, {128, 64}}}
        value = string.gsub(value, "&#x([%x]+)%;", function(h)
            if (tonumber(h, 16) <= 127) then
                return string.char(tonumber(h, 16))
            else
                h = tonumber(h, 16)
                local charbytes = {}
                for b, lim in ipairs(utf8bits) do
                    if h <= lim[1] then
                        for i = b + 1, 2, -1 do
                            local prefix, max = lim[i + 1][1], lim[i + 1][2]
                            local mod = h % max
                            charbytes[i] = string.char(prefix + mod)
                            h = (h - mod) / max
                        end
                        charbytes[1] = string.char(h + lim[2][1])
                        break
                    end
                end
                return table.concat(charbytes)
            end
        end);
        value = string.gsub(value, "&#([0-9]+)%;", function(h)
            if (tonumber(h, 10) <= 127) then
                return string.char(tonumber(h, 10))
            else
                h = tonumber(h, 10)
                local charbytes = {}
                for b, lim in ipairs(utf8bits) do
                    if h <= lim[1] then
                        for i = b + 1, 2, -1 do
                            local prefix, max = lim[i + 1][1], lim[i + 1][2]
                            local mod = h % max
                            charbytes[i] = string.char(prefix + mod)
                            h = (h - mod) / max
                        end
                        charbytes[1] = string.char(h + lim[2][1])
                        break
                    end
                end
                return table.concat(charbytes)
            end
        end);
        value = string.gsub(value, "&quot;", "\"");
        value = string.gsub(value, "&apos;", "'");
        value = string.gsub(value, "&gt;", ">");
        value = string.gsub(value, "&lt;", "<");
        value = string.gsub(value, "&amp;", "&");
        return value;
    end

    function XmlParser:ParseArgs(node, s)
        string.gsub(s, "(%w+)=([\"'])(.-)%2", function(w, _, a)
            node:addProperty(w, self:FromXmlString(a))
        end)
    end

    function XmlParser:ParseXmlText(xmlText)
        local stack = {}
        local top = xmlSimple.newNode()
        table.insert(stack, top)
        local ni, c, label, xarg, empty
        local i, j = 1, 1
        while true do
            ni, j, c, label, xarg, empty = string.find(xmlText, "<(%/?)([%w_:]+)(.-)(%/?)>", i)
            if not ni then
                break
            end
            local text = string.sub(xmlText, i, ni - 1);
            if not string.find(text, "^%s*$") then
                local lVal = (top:value() or "") .. self:FromXmlString(text)
                stack[#stack]:setValue(lVal)
            end
            if empty == "/" then -- empty element tag
                local lNode = xmlSimple.newNode(label)
                self:ParseArgs(lNode, xarg)
                top:addChild(lNode)
            elseif c == "" then -- start tag
                local lNode = xmlSimple.newNode(label)
                self:ParseArgs(lNode, xarg)
                table.insert(stack, lNode)
                top = lNode
            else -- end tag
                local toclose = table.remove(stack) -- remove top

                top = stack[#stack]
                if #stack < 1 then
                    return nil, "XmlParser: nothing to close with " .. label
                end
                if toclose:name() ~= label then
                    return nil, "XmlParser: trying to close " .. toclose.name .. " with " .. label
                end
                top:addChild(toclose)
            end
            i = j + 1
        end
        local text = string.sub(xmlText, i);
        if #stack > 1 then
            return nil, "XmlParser: unclosed " .. stack[#stack]:name()
        end
        return top
    end

    function XmlParser:loadFile(xmlFilename, base)
        if not base then
            base = system.ResourceDirectory
        end

        local path = system.pathForFile(xmlFilename, base)
        local hFile, err = io.open(path, "r");

        if hFile and not err then
            local xmlText = hFile:read("*a"); -- read file content
            io.close(hFile);
            return self:ParseXmlText(xmlText), nil;
        else
            print(err)
            return nil
        end
    end

    return XmlParser
end

function xmlSimple.newNode(name)
    local node = {}
    node.___value = nil
    node.___name = name
    node.___children = {}
    node.___props = {}
    node.___data = {}

    function node:value()
        return self.___value
    end
    function node:setValue(val)
        self.___value = val
    end
    function node:name()
        return self.___name
    end
    function node:setName(name)
        self.___name = name
    end
    function node:children()
        return self.___children
    end
    function node:numChildren()
        return #self.___children
    end
    function node:addChild(child)
        if self.___data[child:name()] ~= nil then
            --[[
            if type(self.___data[child:name()].name) == "function" then
                local tempTable = {}
                table.insert(tempTable, self.___data[child:name()])
                self.___data[child:name()] = tempTable
            end
            ]]
            table.insert(self.___data[child:name()], child)
        else
            self.___data[child:name()] = child
        end
        table.insert(self.___children, child)
    end

    function node:properties()
        return self.___props
    end
    function node:numProperties()
        return #self.___props
    end
    function node:addProperty(name, value)
        local lName = "@" .. name
        if self.___data[lName] ~= nil then
            if type(self.___data[lName]) == "string" then
                local tempTable = {}
                table.insert(tempTable, self.___data[lName])
                self.___data[lName] = tempTable
            end
            table.insert(self.___data[lName], value)
        else
            self.___data[lName] = value
        end
        table.insert(self.___props, {
            name = name,
            value = self.___data[lName]
        })
    end

    return node
end

return xmlSimple
