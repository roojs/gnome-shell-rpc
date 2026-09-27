# Virtual functions

Two programs are involved. The **server** is `mutter-rpc`. It runs real Clutter, in Mutter, and lays out the actors on screen. The **client** is `gnome-shell-rpc`. It runs the shell's JavaScript and Vala. Each program has its own class for an actor. The server's class is not the client's class.

A virtual call does not look the method up by name. It loads a function pointer from a fixed field of whichever class it has, and calls that.

On the **server**, Clutter lays an actor out with this call. `klass` is the server's class:

```c
klass->allocate (actor, box);
```

That is a field read. The C compiler baked in how many bytes `allocate` sits from the start of the class. `OFFSET_OF_allocate` below is that byte count:

```c
void (*fn) (ClutterActor *, const ClutterActorBox *);
fn = *(void **) ((char *) klass + OFFSET_OF_allocate);
fn (actor, box);
```

On the **client**, the shell's class is a different struct in the other program. The client cannot watch the server's `klass`. When the client actor is created it reads its own class at the same byte count, and compares that pointer with a plain widget's. The byte count comes from the typelib, which records where `allocate` sits in the real Clutter class the server is running:

```c
int offset = vfunc_offset ("Clutter", "Actor", "allocate"); /* the server's OFFSET_OF_allocate */
void *ours  = *(void **) ((char *) client_class + offset);
void *plain = *(void **) ((char *) st_widget_class + offset);
if (ours != plain)
    /* remember this byte count; it goes out with create, below */
```

That comparison is how the client discovers the replacement, and it happens at a particular moment.

**When.** The class pointer is filled earlier, when the class is initialized, before any instance exists. Nobody looks at it then. The look happens the first time an instance is constructed. The actor constructor in `Actor.override.vala` walks up to `StWidget` and calls `create_with_overrides`. Inside that, `VfuncRelay.overridden` does the comparison and stores the set of replaced names on the class. The next instance of the same class reuses the set. It does not read the pointers again.

**How.** `overridden` asks the typelib for every virtual name of `Clutter.Actor`. For each name, `vfunc_slot` takes that class, peeks it (`class_peek`), adds the typelib byte count, and loads the function pointer. It does the same load on `StWidget`. For `allocate` that is the `ours` and `plain` lines above. The name is recorded as replaced only when the two pointers are not the same.

The server never reads either class pointer. What it receives, with the create request, is the list of byte counts whose pointers differed, each one paired with a callback. It stores that list on the new actor before it returns the lease:

```c
/* server, ClutterActor.vala — create, before the lease is returned */
peer.vfuncs.set (offset, hook);   /* map: byte count → "call this client callback" */
```

There is no later check for "was allocate replaced?" The map is the record. An entry is there only when the client already decided the method was replaced. `add_hook` is a separate call, for an actor that already existed (the stage). A new actor does not use it.

**Client** (`gnome-shell-rpc`), once, when the actor is created. This class is `WorkspaceBackground` or the JavaScript subclass. The sizing function lives here.

```c
/* Actor.override.vala — create_with_overrides. This order is the whole of it. */

/* 1. Local. No lease yet. The ours/plain read, saved as a list of names. */
names = overridden (this_class, "Clutter", "Actor", "StWidget");

/* 2. Each name is a callback. Register the callback. It does not need a lease.
      The id is a byte count. Ask the typelib which field sits at that byte,
      and keep that name. */
for (name in names) {
    id = offset_of (name);
    called = typelib_name_at (id);          /* vfunc_names + vfunc_offset */
    method_names.add (called);
    method_ids.add (id);
    callback_ids.add (register_callback (name));
}

/* 3. One create. Names, byte counts, and callbacks, same length.
      The server stores the map, then returns the lease. */
lease_id = HelperActor.create (type_name, method_names, method_ids, callback_ids);
```

The lease is the reply to that create. The actor is not addressable before the map is stored. Sending the type name first and the methods afterwards left a leased actor with an empty map; that split is closed: [`bugs/done/2026-09-27-actor-created-before-overrides.md`](bugs/done/2026-09-27-actor-created-before-overrides.md).

**Server** (`mutter-rpc`), every time Clutter lays the helper out. This class is the helper, a plain widget living in Mutter. Its `allocate` is our helper method, not the shell's function. The shell's function is not in this process.

```c
/* ClutterActor.vala — Helper.allocate, which is klass->allocate on the server */
hook = vfuncs.get (allocate_id);   /* allocate_id is that same offset */
if (hook == null)
    base.allocate (box);            /* plain widget layout; children stay 0×0 */
else
    call hook;                      /* RPC back to the client */
```

**Client again**, inside that callback. This is the load from the third block, used as a call.

```c
/* Actor.override.vala — relay_allocate, via c-vfunc-relay.c */
fn = *(void **) ((char *) this_class + offset);
fn (actor, box);                    /* the sizing function, if it was stored at offset */
```

If create did not include the method, the server takes the `hook == null` branch and the picture stays 0×0. The read that decides whether the method is in that list happens only on the client, on the client class. The server never looks at that class.

The rest of this page is why `offset` has to be the real library's, and why the client read misses the function on our generated classes.

Signal delivery is [Client-side signals](signals-client.md). Layout steps are [Clutter layout / allocate](clutter-layout-allocate.md).

## Terminology

| Term | Meaning |
| --- | --- |
| **class struct** | The C struct of function pointers for one class. One copy is shared by every instance of that class. |
| **field** | One method in that struct. `allocate` is a field. |
| **offset** | How many bytes from the start of the struct that field sits at. The C compiler fixed it when the library was built. |
| **typelib** | The installed description of the real library. It records each field's name and offset. GJS uses it. So do we. |
| **baseline** | A class that did not replace the method. For actors we compare with `StWidget`. A different pointer means this class replaced it. |
| **hook** | The client's instruction to the server: when you would call this method, ask me, and I will call the function in my class. |

## Why the call has no name

In the real library, layout ends in one C call:

```c
klass->allocate (actor, box);
```

`allocate` here is a field, not a search. The compiler already turned the name into an offset. At run time the machine loads whatever function pointer is stored at that offset and calls it.

A subclass does not register anywhere else. GObject copies the parent class struct, then the subclass writes a new pointer into the fields it implements. The only record that "this class has its own allocate" is that the pointer in the allocate field is no longer the parent's pointer.

GJS does the same write. `vfunc_allocate` in JavaScript is installed by looking up `allocate` in the typelib, taking that offset, and storing a trampoline there. There is no second table.

## Why we read that same place

The server runs real Clutter. Its `klass->allocate` is the helper widget's function, in the server process. The shell's function is on the client class. The server cannot see it.

So the client looks at its own class and asks whether the allocate field was replaced. That question is:

1. Take the typelib offset for `Clutter.Actor.allocate`. That number is the real library's field position. GJS writes there, so a JavaScript override is visible there.
2. Read the function pointer at that offset on this class.
3. Read the function pointer at that same offset on `StWidget`.
4. If they differ, this class replaced the method. Tell the server to call back here instead of using the plain widget.

When the server does call back, the client reads that same offset again and calls the function stored there. The check and the call are the same load. If the check looked at a different place from the call, we would register a hook and then run the wrong function.

The code is `OLLMrpc.Gi.vfunc_slot` (the load) and `VfuncRelay.overridden` (the comparison). `create_with_overrides` in `Actor.override.vala` runs the comparison once when the actor is created and sends each name that differed with `create`. `c-vfunc-relay.c` does the call.

## Why the place has to be the real library's

The typelib offset is not chosen to suit our stubs. It is the position of the field in the library Mutter actually runs. Two writers already use it:

- GJS, when it installs `vfunc_*`.
- Real Clutter, when it calls `klass->allocate` on a real actor.

Our hook exists to notice those writes and to call them. Looking at any other byte would be looking at a different field, under the name `allocate`.

## Why that read goes wrong on our classes

The client class is not the real `ClutterActorClass`. Vala generates it. The real struct interleaves ordinary methods and signal methods. Vala groups signal methods at the end, so a later field moves to a different byte than the typelib records.

When a class field is also a signal, the generator emits a plain virtual at that byte and a separate signal that is not a class field. Vala parks a virtual signal at the end of the class, which would move every later field. `allocate` sits at the typelib byte because the signals in front of it are plain virtuals. The scan and the callback read that byte.

`c-vfunc-relay.c` calls the typelib offset on purpose, because that is where GJS writes `vfunc_*`. The read is right when the generated field for that name is that byte.

## What this is not

It is not layout deciding, on its own, to ignore a function. Layout on the server calls the helper's allocate. The client was supposed to have registered a hook. It did not, because the pointer it read was the plain one.

It is not a search by method name at call time. The name is used once, to find the offset in the typelib. After that the offset is the method.

It is not the server inspecting the client class. The server only has the hook. The pointer read happens on the client.
