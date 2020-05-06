# InitMe

InitMe is the default Monolith init system. It provides the `io` and `package` APIs, as well as removing all non-standard-Lua APIs from `_G`.

The `package` library only includes `path`, `loaded`, and `searchpath`; no other features were deemed necessary. It also provides `dofile` and `require` implementations.

The `io` library includes all standard functions except `io.tmpfile`.

The `initsvc` library provides the following functions:

- `initsvc.enable(script:string[, isService:boolean]): boolean or nil, string`

  Enable init script/system service `script`. Will not start services or run scripts.

- `initsvc.disable(script:string): boolean or nil, string`

  Disable init script/system service `script`. Will not kill running services.

- `initsvc.start(service:string): boolean or nil, string`

  Start system service `service`

- `initsvc.stop(service:string): boolean or nil, string`

  Stop system service `service`, if found.

`initsvc` will look in `/lib/scripts` and `/lib/services` for scripts and services, respectively.
