-- A storage system. --

local config = require("config")
local logger = require("logger").new("bracket")
local component = require("component")

logger:info("Initializing")

local db = {}

