## Userland documentation

Monolith's userland provides a multitude of APIs, many of which are mostly compatible with their OpenOS counterparts and on which I will not go into detail. I do, however, provide several unique APIs.

### User management

Monolith provides a `users` API, which is a wrapper around `kernel.users` with some more features such as name\<-\>UID mapping.

- `users.login(user:string or number, password:string): boolean or nil, string`

  Attempts to login as `user`.

- `users.logout(): boolean`

  Logs out the current user. If not logged in from another account, the current thread will be set to the guest (i.e. unpriveleged) user.

- `users.sudo(func:function, user:string or number, password:string):boolean, ... or nil, string`

  Attempts to run `func` as `user`.

- `users.uid()`

  Returns the current user's UID.

- `users.add(name:string, password:string, cansudo:boolean): boolean or nil, string`

  Tries to add a user named `name`.

- `users.del(user:string or number): boolean or nil, string`

  Tries to delete user `user`.

- `users.home()`

  Returns the current user's home directory. Alias for `os.getenv("HOME")`.

- `users.shell()`

  Returns the current user's login shell. Alias for `os.getenv("SHELL")`.

### Table protection

Monolith provides a `protect` function, which effectively makes tables and their metatables completely read-only.

WARNING: `setmetatable` and `getmetatable` are wrapped in the kernel to respect the `__ro` flag in a metatable, making table modification when `mtblro` is true virtually impossible.

Syntax:

- `protect(tbl:table[, mtblro: boolean]): table`

  Protects table `tbl` and, if `mtblro` is `true`, protects the metatable with the `__ro` field as well, making your table *really* read-only.

### Crypto

Monolith provides several crypto algorithms from [philanc's Pure Lua Crypto](https://github.com/philanc/plc), notably sha2, sha3, base64, ec25519, and blake2b, with more possibly coming in the future.

### Config

Monolith includes a `config` library, with the following functions:

- `config.load(file:string[, defaults:table]): table or nil, string`

  Loads and returns configuration in Lua table format from `file`. Optionally sets missing options to `defaults`.

- `config.save(cfg:table, file:string): boolean or nil, string`

  Saves `cfg` to `file`. Uses the `serialization` library under the hood.


### Streams

Monolith ships with a `stream` library with the following functions:

- `stream.new(read:function, write:function, close:function): table`

  Creates a faux file stream.

- `stream.dummy(): table, table`

  Creates two new inverted false streams. Used in `io.popen`.

### Networking

Monolith includes the GERT (GERTi and GERTe) and Minitel networking protocols.
