-- svc --

local shell = require("shell")
local svc = require("initsvc")

local args, opts = shell.parse(...)

if #args < 1 or args[1] ~= "list" and #args < 2 then
  shell.error("usage", "svc enable-<script|service>|disable|start|stop <service>\n       or: svc <service> <operation> ...\n       or: svc list")
  return shell.codes.argument
end

local ok, err
if args[1] == "enable-service" then
  ok, err = svc.enable(args[2], true)
elseif args[1] == "enable-script" then
  ok, err = svc.enable(args[2], false)
elseif args[1] == "disable" then
  ok, err = svc.disable(args[2])
elseif args[1] == "start" then
  ok, err = svc.start(args[2])
elseif args[1] == "stop" then
  ok, err = svc.stop(args[2])
elseif args[1] == "list" then
  local s = svc.list()
  print("RUNNING | NAME")
  for i=1, #s, 1 do
    print(string.format("%7s | %s", tostring(s[i].running), s[i].name))
  end
  ok = true
else
  ok, err = svc.invoke(table.unpack(args))
end

if not ok and err then
  shell.error("svc", err)
  return shell.codes.failure
end
