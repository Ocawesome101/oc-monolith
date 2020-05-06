## Kernel documentation

This document lays out all APIs provided by the Monolith kernel, as available to `init`. Note that APIs may differ significantly in userspace, i.e. shell programs.

### The scheduler (`thread`)

Monolith includes a fairly advanced cooperative scheduler, with smart signal timeouts (i.e. if tgread 1 has a timeout of 14, and thread 2 has a timeout of 6, the scheduler will only pause for up to 6 seconds).

Signals:

- `thread_died(pid:number)`

  Queued on the death of a process.

- `thread_errored(pid:number, reason:string)`

  Queued when a thread errors.

- `ipc(from:number, ...)`

  Local to threads. Sent on IPC communications.

- `signal(from:number, signal:number)`

  Local to threads. Sent on signal reception.
  
Available functions:

- `thread.spawn(func:function, name:string[, handler:function[, env:table[, stdin:table[, stdout:table]]]]): number or nil, string`

  Creates a new thread from `func` with name `name`. Optionally sets the thread's error handler to `handler`, environment to `env`, stdin stream to `stdin`, and stdout to `stdout`. Errors propagate up through thread parents until the scheduler finds an error handler, whereupon said handler will be called.

- `thread.threads(): table`

  Returns a table of PIDs.

- `thread.info([pid:number]): table or nil, string`

  Returns a table of information on thread `pid`, or the current thread if no `pid` is provided.

- `thread.signal(pid:number, signal:number): boolean or nil, string`

  Sends signal `signal` to PID `pid`.

- `thread.ipc(pid:number, ...): boolean or nil, string`

  Sends IPC data `...` to thread `pid`.

`thread` also provides a `signals` field, with the following signals:

- `signals.interrupt`

  Tells the thread that ctrl-C has been pressed.

- `signals.term`

  Sent to threads on shutdown.

- `signals.usr1`

  User signal 1.

- `signals.usr2`

  User signal 2.

- `signals.quit`

  Tells the thread to quit.

- `signals.kill`

  Forcibly ends a thread.


### Filesystems

The Monolith kernel provides a generic interface to filesystem devices. This interface is intended to be mostly compatible with the OpenOS implementation, providing all fields of the `filesystem` component with a few additions:

- `fs.canonical(path:string): string`

  Gets the canonical path of `path`.
  
- `fs.concat(path1:string, path2:string, ...): string`

  Concatenates multiple file paths into one path.

- `fs.get(path:string): table or nil, string`

  Returns the filesystem proxy mounted at `path`.

- `fs.mount(proxy:table or address:string, path:string[, isReadOnly:boolean]): boolean or nil, string`

  Mounts a filesystem at `path`, optionally read-only.

- `fs.mounts(): table`

  Returns a table of all currently mounted filesystems and their path, such that `mnts["/"]` will yield the root filesystem's address.

- `fs.umount(path:string): boolean or nil, string`

  Unmounts the filesystem mounted at `path`.

### Kernel interfaces

Some basic kernel interfaces are provided through the `kernel` table. These include the bootlogger `kernel.logger`, user management through `kernel.users`, and the module service `kernel.module`.

`kernel.logger` provides:

- `logger.log(message:string)`

  Logs `message` to the boot console. Should be removed in `init`.

- `logger.panic(reason:string)`

  Invokes a kernel panic because `reason`s.

`kernel.users` provides:

- `users.authenticate(uid:number, password:string): boolean or nil, string`

  Attempt to authenticate the user `uid` with password `password`.

- `users.login(uid:number, password:string): boolean or nil, string`

  Attempt to log in as the user `uid` with password `password`

- `users.logout(): boolean or nil, string`

  Attempt to log out. Note that this will effectively make the current thread completely unprivileged.

- `users.uid(): number`

  Get the current user's UID. Returns 0 if logged in as root, and -1 if not logged in.

- `users.add(password:string[, cansudo:boolean]): number or nil, string`

  Add a new user wuth password `password`. If `cansudo` is true, the user is allowed to perform `kernel.users.sudo`. Returns the new user's UID.

- `users.del(uid:number): boolean or nil, string`

  Renove user `uid`.

- `users.sudo(uid:number, password:string, func:function): boolean or nil, string`

  Attempts to run function `func` as user `uid`. `password` should be the current user's password.

Note that `kernel.users` is write-protected for security reasons. Only root is allowed to perform `kernel.users.add` and `kernel.users.del`. Some functions in the `kernel.users` defined by `module/users.lua` are overwritten by the scheduler to add thread support.

`kernel.module` provides:

- `module.load(mod:string): boolean or nil, string`

  Attempts to load module `mod`.

- `module.unload(mod:string): boolean or nil, string`

  Attempts to unload module `mod`.

Loaded modules are placed in the `kernel` table.
